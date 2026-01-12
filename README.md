# アセンブラ短歌とは
アセンブラ短歌とは、五・七・五・七・七の31バイト(みそひとバイト)の機械語コードでプログラムを書いてみるという近未来の文化的趣味です。

## macOS（x86_64 / Mach-O）作品
macOS（x86_64 / Mach-O）で動く「アセンブラ短歌」の紹介です。

![アセンブラ短歌 in 神山](https://raw.githubusercontent.com/takesako/asm-tanka/refs/heads/main/kami.jpg)

ソースコード: [kami.s](kami.s)
```
# macOS（x86_64 / Mach-O）
.section __TEXT,__text
.globl _main
_main:
# 5
    push  $2
    push  $4
    pop   %rdx
# 7
    pop   %rdi
    push  $0x0a9ea5e7 # UTF-8
    push  %rsp
# 5
    pop   %rsi
    movl  %edi, %eax
    bswap %eax # 02 00 00 00
# 7
    orl   $4, %eax
    syscall
    movl  %edi, %eax
# 7
    bswap %eax # 02 00 00 00
    orl   $1, %eax
    syscall

```
### アセンブル方法
このコードをアセンブルして機械語に翻訳するには以下のコマンドを実行します。
```
arch -x86_64 clang kami.s
```
Apple Silicon(ARM64)で動かす場合は、Rosettaの`arch -x86_64`コマンド経由で実行します。
エントリポイントを指定したい場合clangに`-e _main`オプションを指定したり、標準Cライブラリを明示的にリンクしたくない場合は`-nostdlib`オプションを追加することもできます。
### 実行方法
エラーがなければ a.out 実行ファイルが生成されますのでRosetta経由でIntelバイナリを実行します。
```
arch -x86_64 ./a.out
```
### 実行結果
```
神
```
### 動作解説
このプログラムはシステムコールを2回呼び出して以下を実行しています。
- 標準エラー出力（fd=2）へ UTF-8 の「神」＋改行の文字列を出力し（write）
- 終了コード2で終了します（exit）

### 逆アセンブル結果
Xcodeに含まれるコマンドラインツールotoolを実行し、Mach-O形式のバイナリファイル（macOS/iOSアプリの実行ファイル）を解析します。
```
otool -xvj a.out
```
### 実行結果
```
(__TEXT,__text) section
_main:
0000000100000f89        6a02                    pushq   $0x2
0000000100000f8b        6a04                    pushq   $0x4
0000000100000f8d        5a                      popq    %rdx
0000000100000f8e        5f                      popq    %rdi
0000000100000f8f        68e7a59e0a              pushq   $0xa9ea5e7                      ## imm = 0xA9EA5E7
0000000100000f94        54                      pushq   %rsp
0000000100000f95        5e                      popq    %rsi
0000000100000f96        89f8                    movl    %edi, %eax
0000000100000f98        0fc8                    bswapl  %eax
0000000100000f9a        83c804                  orl     $0x4, %eax
0000000100000f9d        0f05                    syscall
0000000100000f9f        89f8                    movl    %edi, %eax
0000000100000fa1        0fc8                    bswapl  %eax
0000000100000fa3        83c801                  orl     $0x1, %eax
0000000100000fa6        0f05                    syscall
```
日本の短歌のように、5バイト、7バイト、5バイト、7バイト、7バイトの区切りで機械語が区切られていることがわかります。

### 1. まず全体像（何をしているか）

macOS の x86_64 では syscall 命令でカーネル呼び出し（システムコール）を行います。
- RAX … システムコール番号
- RDI, RSI, RDX, R10, R8, R9 … 第1〜第6引数
をセットして syscall します。

このコードは、write(fd=2, buf=..., n=4) を呼び、その後 exit(status=2) を呼んでいます。

### 2. Mach-O とエントリポイント
```
.section __TEXT,__text
.globl _main
_main:
```
.section __TEXT,__text は Mach-O の 実行コード領域（text セクション）に置く指定です。

._main は C の main に相当するリンカが見るエントリシンボルです（macOS では先頭に _ が付きます）。

### 3. 「5」「7」のコメントの意味

コード中の # 5 や # 7 はコメントなので実行には無関係です。しばしば短歌のように「5-7-5-7-7」を意識して命令を区切る演出として入れています。
これが“アセンブラ短歌”のノリです。

### 4. 1つ目の塊：引数をスタックで作る
```
# 5
    push  $2
    push  $4
    pop   %rdx
# 7
    pop   %rdi
```
ここは write の引数を作っています。

- push $2 で値 2 をスタックへ
- push $4 で値 4 をスタックへ
- pop %rdx で 4 を RDXレジスタへ
- pop %rdi で 2 を RDIレジスタへ

つまり
- RDI = 2 … 第1引数 fd（標準エラー）
- RDX = 4 … 第3引数 nbytes（4バイト書く）
という状態になります。

なぜ mov $2, %rdi みたいにしないのかというと、
短く・字数遊び的に「push」と「pop」で即値ロードをしています。
命令バイト数の都合やリズム感も表現しています。

### 5. 2つ目の塊：UTF-8 文字列をスタックに置いて、ポインタを作る
```
    push  $0x0a9ea5e7 # UTF-8
    push  %rsp
# 5
    pop   %rsi
```
ここがこのコードの肝です。

### 5.1 push $0x0a9ea5e7 は何を置く？

0x0a9ea5e7 は 16進で 4バイトです。x86_64 は リトルエンディアンなので、メモリ上の並びは下位バイトから
```
e7 a5 9e 0a
```
になります。

- e7 a5 9e … UTF-8 の「神」
- 0a … 改行（LF）

つまり、スタック上に **"神\n"（4バイト）**を直接埋め込んでいます。

注意：push imm32 は x86_64 では「符号拡張して8バイト分スタックに積む」動作です。
下位4バイトに文字列の並びが入っていれば、write の長さを 4 にして、上位側の値がどうであれ実害が出ないようにしています。

### 5.2 push %rsp → pop %rsi の意味
- push %rsp は「今のスタック先頭アドレス（= さっき積んだ文字列の先頭）をスタックに積む」
- pop %rsi でそれを RSI に入れる
結果として
- RSI = buf（"神\n" が置かれているアドレス）
になります。これで write の第2引数が揃いました。

### 6. 3つ目の塊：macOS の syscall 番号を「bswap + or」で生成する
```
    movl  %edi, %eax
    bswap %eax # 02 00 00 00
# 7
    orl   $4, %eax
    syscall
```
ここは write のシステムコール番号を作っています。

### 6.1 macOS の syscall 番号の形式

macOS（Darwin / XNU）の x86_64 では、UNIX(BSD)系の syscall は
- RAX = 0x2000000 + <BSD syscall番号>
という形式になります。

BSD の write は 4 です。したがって
- write の syscall 番号は 0x2000004
になります。

### 6.2 movl %edi, %eax → bswap %eax の意味

この時点で EDI = 2（fd）です。

movl %edi, %eax で EAX = 2
となります。

bswap %eax は 32bit のバイト順を逆転します。

0x00000002 を bswap すると

0x02000000 になります。

コメントの # 02 00 00 00 はその見た目（バイト列）を示しています。

### 6.3 orl $4, %eax
```
0x02000000 | 0x00000004 = 0x02000004
```
これで RAX（正確には EAX）が write の syscall 番号になりました。

### 6.4 syscall 実行時点のレジスタ

ここまでで
- RAX = 0x02000004 … write
- RDI = 2 … fd=stderr
- RSI = buf … "神\n"
- RDX = 4 … length=4
ができました。

このあと syscall を呼び出すことで
write(2, "神\n", 4) が実行されます。

### 7. 最後：exit も同じトリックで呼ぶ
```
    movl  %edi, %eax
# 7
    bswap %eax # 02 00 00 00
    orl   $1, %eax
    syscall
```
BSD の exit は 1 です。したがって syscall 番号は
```
0x2000001
```
です。さっきと同じ要領で
- EAX = EDI = 2
- bswap(EAX) = 0x02000000
- or 1 で 0x02000001
となり、exit を呼びます。

### 7.1 exit の引数（終了ステータス）

exit(status) の第1引数は RDI です。ここで RDI は最初に fd としてセットした 2 のままなので、
- exit(2)（終了コード 2）
になります。

### 8. まとめ（このコードの鑑賞ポイント）

- 即値ロードを push/pop でやっている（見た目も短くリズム感がある）
- 文字列を データ領域に置かず、スタックへ直置きする
- macOS の syscall 番号 0x2000000 + n を
- mov eax,2 → bswap で 0x02000000 を作って or で下位ビットを足す
というトリックで生成しています。

## 読みやすいリズミカルな作品
macOS（x86_64 / Mach-O）で動く読みやすいリズミカルな作品です。

ソースコード: [kami2.s](kami2.s)
```
# macOS（x86_64 / Mach-O）
.section __TEXT,__text
.globl _main
_main:
# 5
    push  $0x0a9ea5e7 # UTF-8
# 7
    push  $0x02000004 # write
    pop   %rax
    push  %rsp
# 5
    pop   %rsi
    push  $1
    push  $4
# 7
    pop   %rdx
    pop   %rdi
    syscall
    push  $0
    pop   %rdi
# 7
    movl  $0x02000001, %eax # exit
    syscall
```
### 実行方法
```
arch -x86_64 clang kami.s
arch -x86_64 ./a.out
```
### 実行結果
```
神
```
### 逆アセンブル結果
Xcodeに含まれるコマンドラインツールotoolを実行し、Mach-O形式のバイナリファイル（macOS/iOSアプリの実行ファイル）を解析します。
```
otool -xvj a.out
```
### 実行結果
```
(__TEXT,__text) section
_main:
0000000100000f89        68e7a59e0a              pushq   $0xa9ea5e7                      ## imm = 0xA9EA5E7
0000000100000f8e        6804000002              pushq   $0x2000004                      ## imm = 0x2000004
0000000100000f93        58                      popq    %rax
0000000100000f94        54                      pushq   %rsp
0000000100000f95        5e                      popq    %rsi
0000000100000f96        6a01                    pushq   $0x1
0000000100000f98        6a04                    pushq   $0x4
0000000100000f9a        5a                      popq    %rdx
0000000100000f9b        5f                      popq    %rdi
0000000100000f9c        0f05                    syscall
0000000100000f9e        6a00                    pushq   $0x0
0000000100000fa0        5f                      popq    %rdi
0000000100000fa1        b801000002              movl    $0x2000001, %eax                ## imm = 0x2000001
0000000100000fa6        0f05                    syscall
```
### 動作解説
このプログラムは奇麗にシステムコールを2回呼び出して以下を実行しています。
- 標準エラー出力（fd=1）へ UTF-8 の「神」＋改行の文字列を出力し（write）
- 終了コード0で終了します（exit）
### 鑑賞ポイント
この作品は前より読みやすくなっています。無理に小技を重ねず、syscall番号を定数で置いておく素直な書き方になっています。やっていることは同じで、4バイトの定数をmacOSのx86_64の呼び出し規約どおりに、順番にレジスタへ詰めていくだけです。

最初の push $0x0a9ea5e7 は文字列の材料をスタックに置いています。ここは前回と同じで、リトルエンディアンなのでメモリ上の並びは e7 a5 9e 0a になります。UTF-8として読むと「神」と改行です。4バイトに収まるから、長い文字列バッファを作らずに済みます。

writeの呼び出しに必要なのは rax にシステムコール番号、rdi に出力先、rsi にバッファ先頭、rdx にバイト数です。このコードは教科書通りに作っています。push $0x02000004 をして pop %rax、これでraxがwriteになります。macOSのsyscall番号はLinuxみたいに単純な1とか2とかの数字じゃなくて、0x02000000の系統を使うので、この定数がそのまま出てくるのは分かりやすいです。

push %rsp して pop %rsi で、今のスタック先頭アドレスをrsiに入れています。ここ、実は少しだけ注意が要ります。rspは「今積んだ場所」を指しているので、ここをバッファにすると決めた瞬間に、これ以上スタックをいじりたくなくなります。しかし、この後で push $1 と push $4 をしているので、スタックトップはもう文字列じゃなくなります。じゃあ、壊れてないのか、という話になると、実は壊れていません。rsiは値としては「さっきのアドレス」を握ったままで、後からpushをしても、そのアドレスの内容が書き換わらない限り問題ありません。pushは新しい領域を下に確保していくだけで、既存の4バイトを上書きするわけではないからです。ここがスタックをバッファに使うときの勘所で、下方向に伸びる性質をちゃんと信じている潔い書き方です。

次に push $1 と push $4 をして、pop %rdx、pop %rdi。ここは順番が気になりますが、スタックだからこうなります。最後に積んだ4が先にrdxへ入って、次に1がrdiへ入る。結果として rdi=1 で標準出力、rdx=4 で4バイト書き込み。さっきの「神\n」がstdoutに出ます。syscall で実行。ここまでで目的達成です。pushとpopの組み合わせのリズム感も残ります。

終わり方も素直です。push $0; pop %rdi で終了コード0をrdiに入れて、movl $0x02000001, %eax でexitのsyscall番号をeaxに入れる。movlを使っているのが地味にうまくて、eaxを書き換えるとrax上位がゼロになるので、余計なゴミを気にしなくていい。最後にsyscallで終了。

この作品の良さは、トリックが減っていて読み手の負担が軽いところです。逆に言うと、前の作品の bswap で番号を組み立てるコードは分かる人には気持ちいいけど、初見の学生にはノイズになりやすい。授業で扱うならこっちの版の方が向いています。短く書くための工夫は残しつつ、ちゃんと規約に沿っているし、何をどこに入れているかが追いやすい。アセンブリでやることは結局、引数を正しい場所に置いてsyscallするだけだ、という感覚を掴ませるにはこのコードがちょうどいいのです。

# 参考文献

- [https://kozos.jp/asm-tanka/]
- [https://www.amazon.co.jp/dp/4839949468/]
- [https://www.slideshare.net/slideshow/asm-tankalten/43167759]
- [https://www.slideshare.net/slideshow/assembler-haiku-takesako/34496587]
- [https://tanakamura.github.io/pllp/docs/x8664_language.html]
- [https://www.felixcloutier.com/x86/]
