## 大白话：Unlicense 许可证——你用、改、卖，换命名，你开心就好！

##### ”社区的核心精神“
```js
——如果每份公开的代码都要附加一堆条条框框，劝退很多人主动分享。

——“代码能用、能被改进” 比 “内容归属” 重要得多。
```

##### 遵循Unlicense 许可，还是MIT许可 *法律条文依据
```js
中国内地｜《中华人民共和国著作权法》（2020 年修订）法律明确 “著作权即版权”（第六十二条）
大白话：有权自愿放弃全部！符合《著作权法》和《民法典》的原则！内地法院完全认可！

中国香港｜香港《版权条例》（第 528 章）
大白话：Unlicense 许可，让使用者自由用、改、卖，完全符合香港《版权条例》“许可自由” 的原则。香港法院尊重当事人！

欧盟｜欧盟《信息社会版权指令》（2001/29/EC）核心精神
参考：欧盟法院的相关判例（如 2023 年 T-381/22 案）

美国｜“促进科学和实用艺术的进步”（美国宪法第一条第八款）
```


🔴 <font color="red">遵循 [Unlicense 许可证](https://unlicense.org/#unlicensed-free-software)</font>

🟢 <font color="green">遵循 [早期黑客文化](https://en.wikipedia.org/wiki/Hacker_culture) 是"无限制"的</font>

🔵 <font color="blue">[早期 UNIX](https://en.wikipedia.org/wiki/History_of_Unix) 是"无限制"的</font>



---
### Theos: 编译
```js
cd 文件夹（源代码）

make clean && make package
```

# [看看 👉 theos](https://theos.dev/docs/)

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

----------------------------------------------------------

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
