

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




### Logos: 文件扩展名

| **扩展名** | **处理顺序**                                                                 |
|------------|-----------------------------------------------------------------------------|
| **.x**     | 由 Logos 处理，然后预处理并编译为 Objective-C。                                |
| **.xm**    | 由 Logos 处理，然后预处理并编译为 Objective-C++。                              |
| **.xi**    | 先预处理，Logos 再处理结果，然后编译为 Objective-C。                          |
| **.xmi**   | 先预处理，Logos 再处理结果，然后编译为 Objective-C++。                        |

**.xi** 或 **.xmi** 文件允许在预处理器宏（如 `#define`）中使用 Logos 指令，也可以通过 `#include` 引入其他 Logos 源文件。但不推荐这样做，因为这会导致构建时间延长，重复编译未更改的代码。建议使用 **.x** 和 **.xm** 文件，通过 `extern` 声明共享变量和函数。

这些文件扩展名控制 Theos 等构建系统如何处理 Logos 文件。Logos 本身不关心文件扩展名，无论文件是 Objective-C 还是 Objective-C++ 都能正常工作。



### Theos: 编译

make clean && make package