#!/bin/bash

echo "========================================="
echo "     BabelVoice.com DNS 监控脚本"
echo "========================================="
echo ""
echo "开始时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "1. Nameserver 状态:"
echo "-------------------"
CURRENT_NS=$(dig NS babelvoice.com +short 2>/dev/null | head -2 | tr '\n' ' ')
if [[ "$CURRENT_NS" == *"vercel-dns"* ]]; then
    echo -e "${GREEN}✓ Nameserver已更改为Vercel${NC}"
    echo "  $CURRENT_NS"
else
    echo -e "${YELLOW}⏳ Nameserver还在传播中...${NC}"
    echo "  当前: $CURRENT_NS"
    echo "  目标: ns1.vercel-dns.com ns2.vercel-dns.com"
fi

echo ""
echo "2. DNS A记录解析:"
echo "-----------------"
IP=$(dig babelvoice.com A +short 2>/dev/null | head -1)
if [[ ! -z "$IP" ]] && [[ "$IP" != "198.18.5.141" ]]; then
    echo -e "${GREEN}✓ DNS已解析到: $IP${NC}"
else
    echo -e "${YELLOW}⏳ DNS还未更新 (当前: ${IP:-无})${NC}"
fi

echo ""
echo "3. HTTPS访问测试:"
echo "-----------------"
HTTP_CODE=$(curl -o /dev/null -s -w "%{http_code}" --connect-timeout 5 https://babelvoice.com 2>/dev/null)
if [[ "$HTTP_CODE" == "200" ]]; then
    echo -e "${GREEN}✓ 网站可以访问！HTTP状态码: $HTTP_CODE${NC}"
    echo -e "${GREEN}🎉 成功！您现在可以访问: https://babelvoice.com${NC}"
elif [[ "$HTTP_CODE" != "000" ]]; then
    echo -e "${YELLOW}⚠️ 网站响应但状态码异常: $HTTP_CODE${NC}"
else
    echo -e "${RED}✗ 网站还不能访问${NC}"
fi

echo ""
echo "4. Vercel临时访问地址 (始终可用):"
echo "-----------------------------------"
echo -e "${GREEN}https://babelvoice-78j8oq7tm-0xzoharhuangs-projects.vercel.app${NC}"

echo ""
echo "========================================="
echo "预计等待时间:"
echo "• Nameserver更改: 30分钟-2小时"
echo "• DNS A记录: Nameserver生效后5-10分钟"
echo "• SSL证书: DNS生效后自动配置"
echo ""
echo "建议: 每10分钟运行一次此脚本检查进度"
echo "========================================="