import Foundation
import SwiftProtobuf

// Generated types aliases (from Proto/*.pb.swift)
typealias TranslateRequest = Data_Speech_Ast_TranslateRequest
typealias TranslateResponse = Data_Speech_Ast_TranslateResponse
typealias ReqParams = Data_Speech_Ast_ReqParams
typealias EventType = Data_Speech_Event_Type
typealias RequestMeta = Data_Speech_Common_RequestMeta
typealias ResponseMeta = Data_Speech_Common_ResponseMeta
typealias User = Data_Speech_Understanding_User
typealias Audio = Data_Speech_Understanding_Audio

struct DecodedPayload {
    var sourceText: String?
    var targetText: String?
    var pcm48k: Data?
    var event: EventType?
}

final class WireCodec {
    static let shared = WireCodec()
    
    // 80ms静音帧（16kHz mono PCM16）
    let silentFrame16k80ms: Data = {
        let samples = 16000 / 1000 * 80 // 1280 samples
        return Data(count: samples * 2)
    }()
    
    func encodeStartSession(sessionID: String, sourceLanguage: String = "zh", targetLanguage: String = "en") -> Data {
        var request = TranslateRequest()
        
        // Set event type to StartSession
        request.event = .startSession
        
        // Set request metadata
        var meta = RequestMeta()
        meta.sessionID = sessionID
        meta.sequence = 0
        request.requestMeta = meta
        
        // Set user info
        var user = User()
        // 与 Python 版本保持一致
        user.uid = "simple_realtime"
        user.did = "simple_realtime"
        request.user = user
        
        // Set request parameters
        var params = ReqParams()
        params.mode = "s2s"  // Speech to speech mode
        params.sourceLanguage = sourceLanguage
        params.targetLanguage = targetLanguage
        request.request = params
        
        // Set source audio format (input)
        var sourceAudio = Audio()
        sourceAudio.format = "wav"   // match Python: format="wav"
        sourceAudio.rate = 16000
        sourceAudio.bits = 16
        sourceAudio.channel = 1
        request.sourceAudio = sourceAudio
        
        // Set target audio format (output)
        var targetAudio = Audio()
        targetAudio.format = "pcm"   // raw PCM
        targetAudio.rate = 48000
        targetAudio.bits = 16
        targetAudio.channel = 1
        request.targetAudio = targetAudio
        
        // Enable denoise
        request.denoise = true
        
        // Serialize to binary
        do {
            return try request.serializedData()
        } catch {
            Logger.shared.error("Failed to encode StartSession: \(error)")
            return Data()
        }
    }
    
    func encodeAudioChunk(sessionID: String, pcm16: Data, sequence: Int32 = 0) -> Data {
        var request = TranslateRequest()
        
        // Set event type to TaskRequest for audio chunks
        request.event = .taskRequest
        
        // Set request metadata
        var meta = RequestMeta()
        meta.sessionID = sessionID
        meta.sequence = sequence
        request.requestMeta = meta
        
        // 仅设置音频数据（与 Python 一致，避免重复声明格式引起兼容问题）
        var audio = Audio()
        audio.binaryData = pcm16
        request.sourceAudio = audio
        
        // Serialize to binary
        do {
            return try request.serializedData()
        } catch {
            Logger.shared.error("Failed to encode audio chunk: \(error)")
            return Data()
        }
    }
    
    func decodeResponse(_ data: Data) -> DecodedPayload {
        var payload = DecodedPayload()
        
        do {
            let response = try TranslateResponse(serializedBytes: data)
            Logger.shared.debug("WS event=\(response.event) raw=\(response.event.rawValue) dataLen=\(response.data.count) textLen=\(response.text.count)")
            payload.event = response.event
            
            // Handle different event types
            switch response.event {
            case .ttssentenceStart:
                // Beginning of a new TTS sentence
                Logger.shared.debug("TTS sentence started")
                
            case .ttsresponse:
                // TTS audio data
                if !response.data.isEmpty {
                    payload.pcm48k = response.data
                }
                
            case .ttssentenceEnd:
                // End of TTS sentence
                Logger.shared.debug("TTS sentence ended")
                
            case .sourceSubtitleStart:
                Logger.shared.debug("Source subtitle start")
            case .sourceSubtitleResponse:
                if !response.text.isEmpty { payload.sourceText = response.text }
            case .sourceSubtitleEnd:
                Logger.shared.debug("Source subtitle end")
                
            case .translationSubtitleStart:
                Logger.shared.debug("Translation subtitle start")
            case .translationSubtitleResponse:
                if !response.text.isEmpty { payload.targetText = response.text }
            case .translationSubtitleEnd:
                Logger.shared.debug("Translation subtitle end")
                
            case .sessionStarted:
                Logger.shared.info("Session started successfully")
                
            case .sessionFinished:
                Logger.shared.info("Session finished")
                
            case .sessionFailed:
                if response.hasResponseMeta {
                    let meta = response.responseMeta
                    Logger.shared.error("Session failed: code=\(meta.statusCode), message=\(meta.message)")
                }
                
            case .taskStarted:
                Logger.shared.debug("Task started")
                
            case .taskFinished:
                Logger.shared.debug("Task finished")
                
            case .taskFailed:
                if response.hasResponseMeta {
                    let meta = response.responseMeta
                    Logger.shared.error("Task failed: code=\(meta.statusCode), message=\(meta.message)")
                }
                
            case .audioMuted:
                // Silent period detected
                let duration = response.mutedDurationMs
                Logger.shared.debug("Audio muted for \(duration)ms")
                
            default:
                // Other events
                break
            }
            // Subtitle texts handled above in specific cases
            
        } catch {
            Logger.shared.error("Failed to decode response: \(error)")
        }
        
        return payload
    }
    
    func encodeFinishSession(sessionID: String) -> Data {
        var request = TranslateRequest()
        
        // Set event type to FinishSession
        request.event = .finishSession
        
        // Set request metadata
        var meta = RequestMeta()
        meta.sessionID = sessionID
        request.requestMeta = meta
        
        // Serialize to binary
        do {
            return try request.serializedData()
        } catch {
            Logger.shared.error("Failed to encode FinishSession: \(error)")
            return Data()
        }
    }
}
