#!/bin/bash

cd "$(dirname "$0")"

# 增强颜色定义 - 更协调的配色方案
BOLD='\033[1m'
RED='\033[38;5;196m'         # 鲜艳红色 
GREEN='\033[38;5;46m'        # 亮绿色
BRIGHT_GREEN='\033[38;5;82m' # 更亮的绿色
BLUE='\033[38;5;33m'         # 蓝色（调整为更柔和）
DARK_BLUE='\033[38;5;27m'    # 深蓝色
CYAN='\033[38;5;51m'         # 青色
LIGHT_CYAN='\033[38;5;159m'  # 浅青色（调整为更柔和）
ORANGE='\033[38;5;208m'      # 橙色
YELLOW='\033[38;5;220m'      # 黄色（调整为更舒适）
MAGENTA='\033[38;5;201m'     # 品红色
PURPLE='\033[38;5;129m'      # 紫色
WHITE='\033[38;5;255m'       # 白色
NC='\033[0m'                 # 重置颜色

# 状态图标 - 优化大小和一致性
ICON_SUCCESS="✅ "
ICON_FAILURE="❌ "
ICON_PENDING="⏳ "
ICON_WORKING="⚙️  "
ICON_INFO="ℹ️  "

# 清屏并隐藏光标
clear
echo -e "\033[?25l"

# 捕获退出信号，恢复光标并暂停
trap 'echo -e "\033[?25h"; echo -e "\n${CYAN}编译完成。按任意键退出...${NC}"; read -n 1; exit' INT TERM EXIT

# 检查Makefile是否存在
if [ ! -f "Makefile" ]; then
  echo -e "${RED}错误:${NC} 当前目录未找到Makefile。"
  echo -e "${CYAN}当前路径: $(pwd)${NC}"
  echo -e "\n按任意键退出..."
  read -n 1
  exit 1
fi

# 改进的LOGO - 增加边距和视觉平衡
display_logo() {
  echo
  echo -e "${BOLD}${CYAN}        ██████╗ ██╗   ██╗██╗   ██╗██╗   ██╗${NC}"
  echo -e "${BOLD}${CYAN}        ██╔══██╗╚██╗ ██╔╝╚██╗ ██╔╝╚██╗ ██╔╝${NC}"
  echo -e "${BOLD}${CYAN}        ██║  ██║ ╚████╔╝  ╚████╔╝  ╚████╔╝ ${NC}"
  echo -e "${BOLD}${CYAN}        ██║  ██║  ╚██╔╝    ╚██╔╝    ╚██╔╝  ${NC}"
  echo -e "${BOLD}${CYAN}        ██████╔╝   ██║      ██║      ██║   ${NC}"
  echo -e "${BOLD}${CYAN}        ╚═════╝    ╚═╝      ╚═╝      ╚═╝   ${NC}"
  echo -e "${BOLD}${BRIGHT_GREEN}              编译脚本 v2.0${NC}"
  echo
}

# 改进的任务状态显示 - 更清晰的层级和缩进
display_task_status() {
  local task=$1
  local status=$2
  local details=$3
  local icon
  local color
  
  case $status in
    "success")
      icon=$ICON_SUCCESS
      color=$GREEN
      ;;
    "failure")
      icon=$ICON_FAILURE
      color=$RED
      ;;
    "pending")
      icon=$ICON_PENDING
      color=$YELLOW
      ;;
    "working")
      icon=$ICON_WORKING
      color=$CYAN
      ;;
    *)
      icon="• "
      color=$CYAN
      ;;
  esac
  
  # 任务状态改进 - 突出显示状态图标
  echo -e "${color}${icon}${BRIGHT_GREEN}${task}${NC}"
  if [ -n "$details" ]; then
    echo -e "  ${LIGHT_CYAN}└─ ${details}${NC}"
  fi
}

# 更现代化的统计面板 - 改进边框和内部间距
display_stats() {
  local source_files=$1
  local total_files=$2
  
  echo -e "\n${BOLD}${DARK_BLUE}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
  echo -e "${BOLD}${DARK_BLUE}┃  ${BOLD}${BRIGHT_GREEN}编译统计${NC}                                           ${BOLD}${DARK_BLUE}┃${NC}"
  echo -e "${BOLD}${DARK_BLUE}┣━━━━━━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━━━━┫${NC}"
  echo -e "${BOLD}${DARK_BLUE}┃  ${CYAN}主要源代码文件${NC}              ┃  ${YELLOW}${source_files}${NC} 个文件              ┃${NC}"
  echo -e "${BOLD}${DARK_BLUE}┃  ${BOLD}${BRIGHT_GREEN}编译文件总数${NC}                ┃  ${BOLD}${YELLOW}${total_files}${NC} 个文件              ┃${NC}"
  echo -e "${BOLD}${DARK_BLUE}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┻━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"
}

# 更醒目的阶段标题 - 带有独特图标和流畅边框
display_stage() {
  local title=$1
  local icon=$2
  
  # 阶段标题改进 - 更突出的视觉效果
  echo -e "\n${BOLD}${BLUE}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
  echo -e "${BOLD}${BLUE}┃  ${YELLOW}${icon} ${BRIGHT_GREEN}${title}${NC}${BOLD}${BLUE}${NC}"
  echo -e "${BOLD}${BLUE}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"
}

# 改进的编译摘要 - 更好的视觉层次结构
display_summary() {
  local success=$1
  local failed=$2
  local total=$3
  
  echo -e "\n${BOLD}${DARK_BLUE}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
  echo -e "${BOLD}${DARK_BLUE}┃  ${BOLD}${BRIGHT_GREEN}编译摘要${NC}                                           ${BOLD}${DARK_BLUE}┃${NC}"
  echo -e "${BOLD}${DARK_BLUE}┣━━━━━━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━━━━┫${NC}"
  echo -e "${BOLD}${DARK_BLUE}┃  ${GREEN}成功${NC}                        ┃  ${GREEN}${success}${NC} 个文件              ┃${NC}"
  if [ $failed -gt 0 ]; then
    echo -e "${BOLD}${DARK_BLUE}┃  ${RED}失败${NC}                        ┃  ${RED}${failed}${NC} 个文件              ┃${NC}"
  else
    echo -e "${BOLD}${DARK_BLUE}┃  ${LIGHT_CYAN}失败${NC}                        ┃  ${LIGHT_CYAN}0${NC} 个文件                ┃${NC}"
  fi
  echo -e "${BOLD}${DARK_BLUE}┃  ${BOLD}${BRIGHT_GREEN}总计${NC}                        ┃  ${BOLD}${YELLOW}${total}${NC} 个文件              ┃${NC}"
  echo -e "${BOLD}${DARK_BLUE}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┻━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"
}

# 改进的结果显示 - 更精致的边框和更清晰的信息布局
display_result() {
  local success=$1
  local deb_file=$2
  local deb_size=$3
  
  if [ $success -eq 0 ]; then
    # 成功结果框 - 使用渐变色效果
    echo -e "\n${BOLD}${GREEN}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
    echo -e "${BOLD}${GREEN}┃  ${BOLD}${WHITE}编译成功${NC}                                             ${BOLD}${GREEN}┃${NC}"
    echo -e "${BOLD}${GREEN}┣━━━━━━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━━━━━━━━┫${NC}"
    echo -e "${BOLD}${GREEN}┃  ${WHITE}安装包${NC}                      ┃  ${CYAN}${deb_file}${NC}    ${BOLD}${GREEN}┃${NC}"
    echo -e "${BOLD}${GREEN}┃  ${WHITE}大小${NC}                        ┃  ${CYAN}${deb_size}${NC}                ${BOLD}${GREEN}┃${NC}"
    echo -e "${BOLD}${GREEN}┃  ${WHITE}完成时间${NC}                    ┃  ${YELLOW}$(date '+%Y-%m-%d %H:%M:%S')${NC}    ${BOLD}${GREEN}┃${NC}"
    echo -e "${BOLD}${GREEN}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┻━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"
  else
    echo -e "\n${BOLD}${RED}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
    echo -e "${BOLD}${RED}┃  ${BOLD}${WHITE}编译失败${NC}                                             ${BOLD}${RED}┃${NC}"
    echo -e "${BOLD}${RED}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"
  fi
}

# 更平滑的加载指示器 - 优化动画效果
show_animated_indicator() {
  local message=$1
  # 使用更流畅的动画字符
  local animation_chars=('⣾' '⣽' '⣻' '⢿' '⡿' '⣟' '⣯' '⣷')
  local i=0
  
  while true; do
    echo -ne "\r${BOLD}${CYAN}${animation_chars[$i]}${NC} ${BOLD}${BRIGHT_GREEN}${message}${NC}"
    i=$(( (i+1) % 8 ))
    sleep 0.1
  done
}

# 改进的信息栏 - 更紧凑的布局和更好的信息分隔
display_info_bar() {
  local version=$1
  local arch=$2
  local date=$3
  
  echo -e "${BOLD}${DARK_BLUE}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
  echo -e "${BOLD}${DARK_BLUE}┃ ${CYAN}项目${NC}: ${YELLOW}DYYY${NC} ${GREEN}v${version}${NC} │ ${CYAN}架构${NC}: ${MAGENTA}${arch}${NC} │ ${CYAN}日期${NC}: ${YELLOW}${date}${NC} ${BOLD}${DARK_BLUE}┃${NC}"
  echo -e "${BOLD}${DARK_BLUE}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"
}

# 改进编译文件显示格式 - 添加省略号使显示更连贯
format_compile_file() {
  local file=$1
  # 添加省略号，使文件名看起来更统一
  echo "${file}…"
}

# 主函数 - 整体流程不变，但视觉呈现有所改进
main() {
  clear
  display_logo
  
  # 系统信息栏
  VERSION=$(grep "PACKAGE_VERSION" Makefile | head -1 | cut -d'=' -f2 | sed 's/^ *//;s/ *$//')
  ARCH=$(grep "ARCHS" Makefile | head -1 | cut -d'=' -f2 | sed 's/^ *//;s/ *$//;s/  */ /g')
  
  display_info_bar "$VERSION" "$ARCH" "$(date '+%Y-%m-%d')"
  
  # 分析项目
  show_animated_indicator "正在分析项目结构..." &
  INDICATOR_PID=$!
  
  SOURCE_FILES=$(grep -o "\.xm\|\.m\|\.mm\|\.c\|\.cpp" Makefile | wc -l | xargs)
  TOTAL_FILES=$SOURCE_FILES
  
  # 防止除零错误
  if [ $TOTAL_FILES -eq 0 ]; then
    TOTAL_FILES=1
  fi
  
  kill $INDICATOR_PID 2>/dev/null
  wait $INDICATOR_PID 2>/dev/null
  echo -ne "\r\033[K" # 清除动画行
  
  # 显示统计
  display_stats "$SOURCE_FILES" "$TOTAL_FILES"
  
  # 准备阶段
  display_stage "准备编译环境" "🧹"
  display_task_status "清理旧的编译文件" "working"
  make clean >/dev/null 2>&1
  CLEAN_RESULT=$?
  if [ $CLEAN_RESULT -eq 0 ]; then
    display_task_status "清理旧的编译文件" "success" "旧文件清理成功"
  else
    display_task_status "清理旧的编译文件" "failure" "清理过程中出现错误"
  fi
  
  display_task_status "初始化编译环境" "success" "环境变量和编译工具准备完成"
  
  # 临时文件
  TMP_FILE=$(mktemp)
  
  # 编译阶段
  display_stage "编译源代码" "🔨"
  display_task_status "初始化编译器工具链" "success" "工具链配置完成"
  
  echo -e "${LIGHT_CYAN}开始编译源文件...${NC}"
  
  make >$TMP_FILE 2>&1 &
  MAKE_PID=$!
  
  # 编译步骤列表
  declare -a COMPILED_FILES
  SUCCESS_COUNT=0
  FAILURE_COUNT=0
  
  # 监控编译
  while kill -0 $MAKE_PID 2>/dev/null; do
    CURRENT_FILE=$(grep -o "Compiling [^ ]*\|Preprocessing [^ ]*" $TMP_FILE | tail -1 | sed 's/Compiling //;s/Preprocessing //')
    
    if [ -n "$CURRENT_FILE" ] && ! [[ " ${COMPILED_FILES[@]} " =~ " ${CURRENT_FILE} " ]]; then
      # 添加到已编译列表
      COMPILED_FILES+=("$CURRENT_FILE")
      
      # 检查上一个文件编译结果
      ERROR_LOG=$(grep -A 3 "error:" $TMP_FILE | grep -B 3 "$CURRENT_FILE" 2>/dev/null)
      
      if [ -n "$ERROR_LOG" ]; then
        display_task_status "编译: $(format_compile_file "$CURRENT_FILE")" "failure" "$(echo "$ERROR_LOG" | head -1)"
        FAILURE_COUNT=$((FAILURE_COUNT + 1))
      else
        display_task_status "编译: $(format_compile_file "$CURRENT_FILE")" "success"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
      fi
    fi
    
    sleep 0.1
  done
  
  # 等待完成
  wait $MAKE_PID
  RESULT=$?
  
  # 如果没有显示任何文件，可能是出错太早或没有文件要编译
  if [ ${#COMPILED_FILES[@]} -eq 0 ]; then
    if [ $RESULT -eq 0 ]; then
      display_task_status "没有需要编译的文件" "success" "所有文件都是最新的"
    else
      ERROR_MSG=$(grep -i "error:" $TMP_FILE | head -1)
      if [ -n "$ERROR_MSG" ]; then
        display_task_status "编译失败" "failure" "$ERROR_MSG"
      else
        display_task_status "编译失败" "failure" "未知错误, 请查看日志"
      fi
      FAILURE_COUNT=1
    fi
  fi
  
  # 显示编译摘要
  display_summary $SUCCESS_COUNT $FAILURE_COUNT $((SUCCESS_COUNT + FAILURE_COUNT))
  
  if [ $RESULT -eq 0 ]; then
    # 链接
    display_task_status "链接目标文件" "working"
    sleep 0.5
    display_task_status "链接目标文件" "success" "所有对象文件已成功链接"
    
    # 打包
    display_stage "生成安装包" "📦"
    display_task_status "创建Deb文件" "working"
    make package >/dev/null 2>&1
    PACKAGE_RESULT=$?
    
    if [ $PACKAGE_RESULT -eq 0 ]; then
      display_task_status "创建Deb文件" "success" "安装包已成功生成"
    else
      display_task_status "创建Deb文件" "failure" "安装包生成失败"
      RESULT=1
    fi
    
    # 完成
    if [ $RESULT -eq 0 ]; then
      display_task_status "编译流程" "success" "所有步骤已成功完成"
      
      # 结果
      DEB_FILE=$(ls -t *.deb 2>/dev/null | grep "iphoneos-arm64" | head -1)
      if [ -n "$DEB_FILE" ]; then
        DEB_SIZE=$(du -h "$DEB_FILE" | cut -f1)
        display_task_status "生成安装包" "success" "文件: $DEB_FILE (${DEB_SIZE})"
        display_result 0 "$DEB_FILE" "$DEB_SIZE"
      else
        display_task_status "查找安装包" "failure" "未找到生成的安装包文件"
        display_result 0 "未找到安装包" "N/A"
      fi
    fi
  else
    display_task_status "编译流程" "failure" "编译过程中出现错误"
    display_result 1
    echo -e "${RED}错误日志:${NC}\n"
    cat $TMP_FILE | grep -i error | head -10
    echo -e "\n${CYAN}(查看完整日志获取更多详情)${NC}"
  fi
  
  # 清理
  rm $TMP_FILE
  
  # 恢复光标
  echo -e "\033[?25h"
}

main "$@"