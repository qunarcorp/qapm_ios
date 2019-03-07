//
//  QCacheStorage.h
//  QAPM_a
//
//  Created by mdd on 2018/12/19.
//  Copyright © 2018年 mdd. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface QCacheStorage : UIView

typedef void (^QGetFileDataCompleteBlock)(NSDictionary *data);

typedef void (^QGetFileListCompleteBlock)(NSArray *data);

typedef void (^QSaveFileDataCompleteBlock)(BOOL rlt);

typedef void (^QGetFileNameCompleteBlock)(NSString *fileName);

/**
 @param dirPath 用户自定义文件夹路径，如果创建时目录为空或创建文件夹失败，则使用默认路径，默认路径为：.../Document/QCacheStorage
 */
+ (instancetype)cacheStorageWithDir:(NSString *)dirPath;
- (BOOL)hasValuedFile;
- (void)deleteFile:(NSString *)fileName;
/// 存储文件到本地或者
- (void)saveData:(NSDictionary *)data toFile:(NSString *)fileName;
/// 根据文件名获取文件
- (void)fileDataWithFile:(NSString *)file withCompleteBlock:(QGetFileDataCompleteBlock)block;
/// 当前所有文件名
- (void)fileLists:(QGetFileListCompleteBlock)block;
/// 根据时间排序获取最早的文件，key为文件名
- (void)earlyFile:(QGetFileDataCompleteBlock) block;
- (void)sendFileErrorAddFile:(NSString *)fileName;
/// block 返回成功或失败
- (void)saveCacheToFile:(QSaveFileDataCompleteBlock) block;
/// 文件夹路径。若用户自定义路径创建文件夹成功则返回用户自定义路径，否则返回默认
- (NSString *)dirPath;
@property (nonatomic, assign) NSUInteger maxCacheSize;
/// 允许存储文件的个数，如果maxFileSize为0则无限制。一个文件大概7KB，1万个文件差不多70MB。如果超过了设定限制，会删掉最早的%5
@property (nonatomic, assign) NSUInteger maxFileSize;
/// 生成一个有序的文件名，方便根据文件名排序
+ (NSString *)autoIncrementFileName;

@end
