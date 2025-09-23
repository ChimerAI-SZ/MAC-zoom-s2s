#!/usr/bin/env python3
"""
健壮性测试脚本 - 模拟长时间运行和频繁操作
"""
import sys
import os
# 添加父目录到路径
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import asyncio
import time
import random
import threading
from typing import List
from logger import logger, set_level
from health_monitor import get_monitor


class RobustnessTest:
    """健壮性测试类"""
    
    def __init__(self):
        self.test_results = []
        self.monitor = get_monitor()
        set_level('DEBUG')
        
    async def test_rapid_start_stop(self, iterations: int = 10):
        """测试频繁启动/停止"""
        logger.info(f"开始测试：频繁启动/停止 ({iterations}次)")
        
        from realtime_simple import SimpleRealtimeTranslator
        
        for i in range(iterations):
            try:
                logger.info(f"迭代 {i+1}/{iterations}")
                
                # 创建翻译器
                translator = SimpleRealtimeTranslator()
                
                # 启动
                task = asyncio.create_task(translator.run())
                
                # 运行随机时间（1-5秒）
                await asyncio.sleep(random.uniform(1, 5))
                
                # 停止
                translator.stop()
                task.cancel()
                
                try:
                    await task
                except asyncio.CancelledError:
                    pass
                
                # 检查健康状态
                status = self.monitor.get_health_status()
                logger.info(f"健康状态: {status['healthy']}, 内存: {status['metrics']['memory_usage_mb']:.1f}MB")
                
                self.test_results.append({
                    'test': 'rapid_start_stop',
                    'iteration': i+1,
                    'success': True,
                    'memory_mb': status['metrics']['memory_usage_mb']
                })
                
            except Exception as e:
                logger.error(f"测试失败 (迭代 {i+1}): {e}")
                self.test_results.append({
                    'test': 'rapid_start_stop',
                    'iteration': i+1,
                    'success': False,
                    'error': str(e)
                })
                
            # 短暂等待
            await asyncio.sleep(0.5)
            
    async def test_language_switching(self, duration_seconds: int = 30):
        """测试频繁切换语言"""
        logger.info(f"开始测试：频繁切换语言 ({duration_seconds}秒)")
        
        from realtime_simple import SimpleRealtimeTranslator
        
        translator = SimpleRealtimeTranslator()
        task = asyncio.create_task(translator.run())
        
        start_time = time.time()
        switch_count = 0
        
        try:
            while time.time() - start_time < duration_seconds:
                # 切换语言
                if translator.source_language == 'zh':
                    translator.source_language = 'en'
                    translator.target_language = 'zh'
                else:
                    translator.source_language = 'zh'
                    translator.target_language = 'en'
                    
                switch_count += 1
                logger.info(f"语言切换 #{switch_count}: {translator.source_language} -> {translator.target_language}")
                
                # 等待1-3秒
                await asyncio.sleep(random.uniform(1, 3))
                
            self.test_results.append({
                'test': 'language_switching',
                'switches': switch_count,
                'success': True
            })
            
        except Exception as e:
            logger.error(f"语言切换测试失败: {e}")
            self.test_results.append({
                'test': 'language_switching',
                'switches': switch_count,
                'success': False,
                'error': str(e)
            })
            
        finally:
            translator.stop()
            task.cancel()
            try:
                await task
            except asyncio.CancelledError:
                pass
                
    async def test_long_running(self, duration_seconds: int = 60):
        """测试长时间运行"""
        logger.info(f"开始测试：长时间运行 ({duration_seconds}秒)")
        
        from realtime_simple import SimpleRealtimeTranslator
        
        translator = SimpleRealtimeTranslator()
        task = asyncio.create_task(translator.run())
        
        start_time = time.time()
        check_interval = 10  # 每10秒检查一次
        
        try:
            while time.time() - start_time < duration_seconds:
                await asyncio.sleep(check_interval)
                
                # 检查健康状态
                status = self.monitor.get_health_status()
                elapsed = time.time() - start_time
                
                logger.info(f"运行时间: {elapsed:.1f}s, "
                          f"内存: {status['metrics']['memory_usage_mb']:.1f}MB, "
                          f"线程: {status['metrics']['thread_count']}, "
                          f"健康: {status['healthy']}")
                
            self.test_results.append({
                'test': 'long_running',
                'duration': duration_seconds,
                'success': True,
                'final_memory_mb': status['metrics']['memory_usage_mb'],
                'final_threads': status['metrics']['thread_count']
            })
            
        except Exception as e:
            logger.error(f"长时间运行测试失败: {e}")
            self.test_results.append({
                'test': 'long_running',
                'duration': time.time() - start_time,
                'success': False,
                'error': str(e)
            })
            
        finally:
            translator.stop()
            task.cancel()
            try:
                await task
            except asyncio.CancelledError:
                pass
                
    async def test_concurrent_operations(self):
        """测试并发操作"""
        logger.info("开始测试：并发操作")
        
        from app_menu import TranslatorManager
        
        manager = TranslatorManager()
        
        async def concurrent_task(task_id: int):
            """并发任务"""
            for _ in range(5):
                try:
                    # 随机操作
                    action = random.choice(['start', 'stop', 'check'])
                    
                    if action == 'start':
                        manager.start(None, None, 'zh', 'en')
                    elif action == 'stop':
                        manager.stop()
                    else:
                        is_running = manager.is_running()
                        logger.debug(f"Task {task_id}: running={is_running}")
                        
                    await asyncio.sleep(random.uniform(0.1, 0.5))
                    
                except Exception as e:
                    logger.error(f"Task {task_id} error: {e}")
                    
        # 启动多个并发任务
        tasks = []
        for i in range(5):
            tasks.append(asyncio.create_task(concurrent_task(i)))
            
        # 等待所有任务完成
        await asyncio.gather(*tasks, return_exceptions=True)
        
        # 最终停止
        manager.stop()
        
        self.test_results.append({
            'test': 'concurrent_operations',
            'success': True
        })
        
    def print_results(self):
        """打印测试结果"""
        print("\n" + "="*50)
        print("健壮性测试结果")
        print("="*50)
        
        for result in self.test_results:
            test_name = result['test']
            success = result.get('success', False)
            status = "✅ 通过" if success else "❌ 失败"
            
            print(f"\n测试: {test_name}")
            print(f"状态: {status}")
            
            # 打印额外信息
            for key, value in result.items():
                if key not in ['test', 'success']:
                    print(f"  {key}: {value}")
                    
        # 总结
        total = len(self.test_results)
        passed = sum(1 for r in self.test_results if r.get('success', False))
        print(f"\n总结: {passed}/{total} 测试通过")
        
        # 最终健康状态
        final_status = self.monitor.get_health_status()
        print(f"\n最终健康状态:")
        print(f"  健康: {final_status['healthy']}")
        print(f"  内存: {final_status['metrics']['memory_usage_mb']:.1f}MB")
        print(f"  线程: {final_status['metrics']['thread_count']}")
        print(f"  错误: {final_status['metrics']['error_count']}")


async def main():
    """主测试函数"""
    tester = RobustnessTest()
    
    # 启动健康监控
    monitor = get_monitor()
    monitor.start()
    
    try:
        # 运行各项测试
        print("开始健壮性测试...")
        
        # 1. 频繁启动/停止测试
        await tester.test_rapid_start_stop(iterations=5)
        
        # 2. 语言切换测试
        await tester.test_language_switching(duration_seconds=20)
        
        # 3. 长时间运行测试
        await tester.test_long_running(duration_seconds=30)
        
        # 4. 并发操作测试
        await tester.test_concurrent_operations()
        
    except KeyboardInterrupt:
        logger.info("测试被用户中断")
        
    finally:
        # 停止监控
        monitor.stop()
        
        # 打印结果
        tester.print_results()
        

if __name__ == "__main__":
    print("S2S 健壮性测试")
    print("================")
    print("此测试将模拟各种极端使用场景")
    print("预计运行时间：2-3分钟")
    print("")
    
    asyncio.run(main())