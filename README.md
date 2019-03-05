## 功能介绍

QAPM是去哪儿使用的APP监控系统。已在内部稳定运行3年。提供功能如下：网络请求时长、网络数据流量、网络请求成功或失败以及失败原因等。帧率检测、CPU使用率、电池电量。

## 如何使用

* 支持iOS8以上版本
* 包含头文件`#import "QAPManager.h"`

* 在程序启动`didFinishLaunchingWithOptions`调用初始化方法，参数均必传。

```

pid 产品号，假设公司有多个APP，用此区分
cid 渠道标识，比如越狱渠道、App Store、自己分发等等
vid 版本号，程序版本号，一般内部使用
uid 设备号，唯一区分一台设备，比如idfa

+ (void)startWithPid:(nonnull NSString *)pid
                 cid:(nullable NSString *)cid
                 vid:(nullable NSString *)vid
                 uid:(nullable NSString *)uid;
```



* 其它一些设置

```
/**
 域名过滤，当请求的url.absoluteString包含set的内容时，不上传监控数据。实时生效
 域名比如 苹果网站:www.apple.com , 或者更具体的 www.apple.com/watch ，但是前者已包含后者
 */
@property (nonatomic, strong) NSArray<NSString *> *domainFilterList;
```

## 网络数据收集部分

比较通用的策略：一般有三种

* 一、NSURLProtocol
* 二、hook NSURLSession NSURLConnection
* 三、苹果提供的 NSURLSessionTaskMetrics

我们采用第二种，第三种作为辅助。不使用第一种主要是因为兼容性不好，如果另外一个人也实现了NSURLProtocol，他也拦截，那我们就拦截不了了。除非他能再把这个请求重新发一遍，但是这样就对代码侵入太多了。

NSURLSessionTaskMetrics 时间信息全，且准确，比较真实的网络请求时间（用hook方法，会有延时，特别是请求多，CPU繁忙时）。只是官方只支持NSURLSession且iOS10以后，想监控iOS8、iOS9、NSURLConnection就需要使用私有API了，有上架风险。且`[NSURLSession sharedSession]`也没有找到合适的解决方案实现监控。

总结下：

hook方式获取网络的请求时长，流量、状态。iOS10以后NSURLSession 的非`[NSURLSession sharedSession]`发出请求用NSURLSessionTaskMetrics方式作为补充。因为它计算出来的流量、网速更真实。而hook计算出来的更贴近开发者，也更贴近用户的体验感受，两者各有用途。

#### 统计范围

整体统计范围：

* 通过NSURLSession、NSURLConnection发出的请求均会统计到。
* UIWebview、WKWebview的ajax请求统计不到
* TCP请求统计不到

一些过滤：

* 请求发生在后台，或者请求过程中有退到后台
* 请求被主动取消
* 请求url长度等于0的
* 图片请求(pathExtension 包含 png、jpg、jpeg、gif、webp判定为图片请求)成功且时长小于2秒
* 请求url是 网络监控日志上传发出的请求
* 只统计url 以 http:// 或者 https://  开头的

## 存储上传部分大致实现

* 存储和上传都在一个串行队列执行，线程安全
* 日志会以10条作为一个文件，存入内存，当内存超过5个文件时，存入磁盘。
* 够10条则上传，一次上传一个文件。上传成功删除文件。

如果想查看，存的日志可以：

* 包含头文件`#import "QAPManager.h"`
* 获取文件操作实例：`+ (QCacheStorage *)releaseLogInstance;`
* 在头文件`#import "QCacheStorage.h"`中提供一下方法：

```
/// 获取当前所有文件名
- (void)fileLists:(QGetFileListCompleteBlock)block;
/// 根据文件名，删除一个文件
- (void)deleteFile:(NSString *)fileName;
/// 存储文件到本地或者
- (void)saveData:(NSDictionary *)data toFile:(NSString *)fileName;
/// 根据文件名获取文件
- (void)fileDataWithFile:(NSString *)file withCompleteBlock:(QGetFileDataCompleteBlock)block;
```






