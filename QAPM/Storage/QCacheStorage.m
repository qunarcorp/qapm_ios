//
//  QCacheStorage.m
//  QAPM_a
//
//  Created by mdd on 2018/12/19.
//  Copyright © 2018年 mdd. All rights reserved.
//

#import "QCacheStorage.h"

//#define kMaxCacheSize  5

static NSString *const gStringQCacheDirName = @"/QCacheStorage";

@interface QCacheStorage ()
/// 当前的所有文件名（后续可以做成最早或者最晚的n个文件）
@property (nonatomic, strong) NSMutableArray *pendingFiles;

/// 内存缓存中间层，使日志读写更高效，同时减少文件读写次数
@property (nonatomic, strong) NSMutableDictionary *memoryCacher;
/// 串行队列
@property (nonatomic, strong) dispatch_queue_t squeue;
@property (nonatomic, copy) NSString *dirPath;
@end

@implementation QCacheStorage
/// 避免同一个dirPath重复调用此方法多次！！！待处理
+ (instancetype)cacheStorageWithDir:(NSString *)dirPath {
    QCacheStorage *cacheStorage = [[QCacheStorage alloc] init];
    cacheStorage.squeue = dispatch_queue_create("QCacheStorageQueue", DISPATCH_QUEUE_SERIAL);
    cacheStorage.dirPath = dirPath;
    cacheStorage.pendingFiles = [NSMutableArray arrayWithCapacity:1];
    if (![cacheStorage createDirectory:dirPath]) {
        cacheStorage.dirPath = nil;
        [cacheStorage createDirectory:[self defaultDirectory]];
    }
    cacheStorage.pendingFiles = [cacheStorage _existingDataFiles].mutableCopy;
    return cacheStorage;
}

#pragma mark - 对外提供api

/// 返回最近的{文件名:文件数据}
- (void)latelyFile:(QGetFileDataCompleteBlock) block {
    if (!block) {
        return;
    }
    dispatch_async(self.squeue, ^{
        if (self.pendingFiles.count > 0) {
            NSString *key = self.pendingFiles.lastObject;
            NSDictionary *data = [self _dataFromFile:key];
            if (key && data) {
                block(@{key:data});
            }
            [self.pendingFiles removeObjectAtIndex:self.pendingFiles.count - 1];
        }
        else {
            block(nil);
        }
    });
}

- (void)fileLists:(QGetFileListCompleteBlock)block {
    if (!block) {
        return;
    }
    dispatch_async(self.squeue, ^{
        block([self.pendingFiles copy]);
    });
}

- (void)fileDataWithFile:(NSString *)file withCompleteBlock:(QGetFileDataCompleteBlock)block {
    if (!block) {
        return;
    }
    if (file) {
        dispatch_async(self.squeue, ^{
            NSDictionary *data = [self _dataFromFile:file];
            block(data);
        });
    }
    else {
        block(nil);
    }
}

/// 返回最早的{文件名:文件数据}
- (void)earlyFile:(QGetFileDataCompleteBlock)block {
    if (!block) {
        return;
    }
    dispatch_async(self.squeue, ^{
        if (self.pendingFiles.count > 0) {
            NSString *key = self.pendingFiles.firstObject;
            NSDictionary *data = [self _dataFromFile:key];
            if (key && data) {
                block(@{key:data});
            }
            else {
                block(nil);
            }
            [self.pendingFiles removeObjectAtIndex:0];
        }
        else {
            block(nil);
        }
    });
}
/// 发送文件失败，将文件再写到pendingFiles
- (void)sendFileErrorAddFile:(NSString *)fileName {
    if (!fileName) {
        return;
    }
    dispatch_async(self.squeue, ^{
        [self.pendingFiles insertObject:fileName atIndex:0];
    });
}

- (BOOL)hasValuedFile {
    return self.pendingFiles.count > 0;
}

/**
 Document/QCacheStorage
 */
+ (NSString *)defaultDirectory {
    NSString *defaultDirectory = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    NSString *rlt = [defaultDirectory stringByAppendingPathComponent:gStringQCacheDirName];
    return rlt;
}
/// 生成一个有序的文件名，下次读取时方便根据文件名排序
+ (NSString *)autoIncrementFileName {
    // 时间戳可能不唯一，采用时间戳+自增数的逻辑。自增数每次启动时变为0不会有问题，因为前面的时间戳一定是更大的
    static long long index = 0;
    NSString *curTimeStamp = [NSString stringWithFormat:@"%llu",(unsigned long long)([[NSDate date] timeIntervalSince1970])];
    return [NSString stringWithFormat:@"QCS_%@_%lld",curTimeStamp, ++index];
}

- (NSString *)dirPath {
    if (!_dirPath) {
        return [QCacheStorage defaultDirectory];
    }
    return _dirPath;
}
/// 存储文件到本地或者内存
- (void)saveData:(NSDictionary *)data toFile:(NSString *)fileName {
    dispatch_async(self.squeue, ^{
        [self.pendingFiles addObject:fileName];
        [self.memoryCacher setObject:data forKey:fileName];
        if ([self.memoryCacher count] >= MAX(self.maxCacheSize, 1) ) {
            // 把现有的内存缓存日志存到本地
            [self _saveCacheToFile];
        }
    });
}

/// 从缓存或者本地删掉文件
- (void)deleteFile:(NSString *)fileName {
    dispatch_async(self.squeue, ^{
        if (fileName == nil || fileName.length == 0) { return ; }
        // 删除本地文件
        if ([self.memoryCacher objectForKey:fileName]) {
            // 如果在内存缓存中，则直接删除
            [self.memoryCacher removeObjectForKey:fileName];
        } else {
            NSFileManager *fileManager = [NSFileManager defaultManager];
            [fileManager removeItemAtPath:[self saveFilePathWithFileName:fileName] error:nil];
        }
    });
}

/// 进入后台时全部存到本地
- (void)saveCacheToFile:(QSaveFileDataCompleteBlock) block{
    dispatch_async(self.squeue, ^{
        BOOL rlt = [self _saveCacheToFile];
        if (block) {
            block(rlt);
        }
    });
}
/// 取出文件
- (void)dataFromFile:(NSString *)fileName withComplete:(QGetFileDataCompleteBlock) block{
    if (!block) {
        return;
    }
    dispatch_async(self.squeue, ^{
        block([self _dataFromFile:fileName]);
    });
}

- (void)existingDataFiles:(QGetFileListCompleteBlock)block {
    if (!block) {
        return;
    }
    dispatch_async(self.squeue, ^{
        block([self _existingDataFiles]);
    });
}

#pragma mark - 对外提供api对应的内部方法

- (BOOL)_saveCacheToFile {
    // 并非把所有缓存写入一个文件，而依然是单独写入各自的文件。之所以这样做是考虑到如果写入一个文件中，那么当需要其中任意一个时都需要把整个文件全量读出。
    __block BOOL rlt = YES;
    [self.memoryCacher enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, NSDictionary * _Nonnull logs, BOOL * _Nonnull stop) {
        if ([logs writeToFile:[self saveFilePathWithFileName:key] atomically:YES]) {
            [self.memoryCacher removeObjectForKey:key];
        } else {
            rlt = NO;
            *stop = YES;
        }
    }];
    return rlt;
}

- (NSDictionary *)_dataFromFile:(NSString *)fileName {
    NSDictionary *cachedLogs = [self.memoryCacher objectForKey:fileName];
    if (cachedLogs) {
        return cachedLogs;
    }
    // 去本地找
    cachedLogs = [NSDictionary dictionaryWithContentsOfFile:[self saveFilePathWithFileName:fileName]];
    return cachedLogs;
}

- (NSArray *)_existingDataFiles {
    // 缓存中的所有key + 本地的所有文件
    NSArray *sortedCachedKeys = [self.memoryCacher allKeys];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    // 比较耗时，采用一级目录，避免更大的耗时
    NSArray *rlt = [fileManager subpathsAtPath:[self dirPath]];
    sortedCachedKeys = [[sortedCachedKeys arrayByAddingObjectsFromArray:rlt] sortedArrayUsingComparator:^NSComparisonResult(NSString*  _Nonnull obj1, NSString*  _Nonnull obj2) {
        return [obj1 compare:obj2];
    }];
    return sortedCachedKeys;
}

#pragma mark - 内部方法

- (NSString *)saveFilePathWithFileName:(NSString *)fileName {
    NSString *rlt = [[self dirPath] stringByAppendingPathComponent:[NSString stringWithFormat:@"/%@", fileName]];
    return rlt;
}

- (NSMutableDictionary *)memoryCacher {
    if (_memoryCacher == nil) {
        _memoryCacher = [NSMutableDictionary dictionaryWithCapacity:self.maxCacheSize];
    }
    return _memoryCacher;
}

/**
 日志存储文件夹
 */
- (BOOL)createDirectory:(NSString *)dirPath {
    if (dirPath == nil) {
        return NO;
    }
    // 文件夹不存在时新建
    BOOL isDir = NO;
    BOOL rlt = YES;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:dirPath isDirectory:&isDir]) {
        rlt = [fileManager createDirectoryAtPath:dirPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return rlt;
}

@end

