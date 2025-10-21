
🔴 <font color="red">遵循 [Unlicense 许可证](https://unlicense.org/#unlicensed-free-software)</font>

🟢 <font color="green">遵循 [早期黑客文化](https://en.wikipedia.org/wiki/Hacker_culture) 是"无限制"的</font>

🔵 <font color="blue">[早期 UNIX](https://en.wikipedia.org/wiki/History_of_Unix) 是"无限制"的</font>

🟣 <font color="purple">无需保留署名</font>

🟠 <font color="orange">自由使用、修改、分发</font>

---
# [看看 👉 theos](https://theos.dev/docs/)

### Logos: 文件扩展名

| **扩展名** | **处理顺序**                                                                 |
|------------|-----------------------------------------------------------------------------|
| **.x**     | Logos 处理并编译为 Objective-C                               |
| **.xm**    | Logos 处理并编译为 Objective-C++                            |
| **.xi**    | 先预处理，Logos 再处理结果，然后编译为 Objective-C                          |
| **.xmi**   | 先预处理，Logos 再处理结果，然后编译为 Objective-C++                       |

### Theos: 编译

make clean && make package




```js
终端执行 克隆 Theos 仓库
git clone --recursive https://github.com/theos/theos.git

将 Theos 的路径添加到环境变量中：
方法一：
终端执行 直接添加到 ~/theos

export THEOS=~/theos
export PATH=$THEOS/bin:$PATH

终端执行  重新 加载配置：
source ~/.zshrc

另一种方法：
终端执行 打开配置文件 .zshrc
nano ~/.zshrc

# Theos 配置  // theos文件夹 的本地路径
export THEOS=/Users/pxx917144686/theos     

之后；contron + X 是退出编辑； 按‘y’ 保存编辑退出！

终端执行  重新 加载配置：
source ~/.zshrc
```

</td>
</tr>
</table>

</details>
