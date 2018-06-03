//
//  ServerViewController.m
//  ByteData
//
//  Created by L's on 2018/6/3.
//  Copyright © 2018年 zuiye. All rights reserved.
//

#import "ServerViewController.h"
#import "AsyncSocket.h"

@interface ServerViewController ()<AsyncSocketDelegate>
{
    NSInteger _isHeader;
    NSInteger _fileLength;
}

/** <#description#> */
@property (nonatomic, strong) AsyncSocket* serverSocket;

/** 当前连接的客户端 */
@property (nonatomic, strong) AsyncSocket* clientSocket;

@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UITextView *textView;

@end

@implementation ServerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self deleteFile];
    _isHeader = NO;
    _fileLength = 0;
    self.serverSocket = [[AsyncSocket alloc] initWithDelegate:self];
    [self openPort];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark
-(IBAction)clearCache:(id)sender{

    self.imageView.image = nil;
    self.textView.text = @"";
}

#pragma mark - method
-(void)openPort{
    
    NSError* error;
    BOOL success = [self.serverSocket acceptOnPort:8080 error:&error];
    if (success && !error) {
        NSLog(@"端口开放成功");
        self.textView.text = [self.textView.text stringByAppendingFormat:@"\n%@", @"端口开放成功"];
    }else{
        NSLog(@"端口开放失败：%@", error);
    }
}

-(void)sendMsgSock:(AsyncSocket*)sock{
    NSString* replyText = @"接收完成了，别给我发了";
    NSData* data = [replyText dataUsingEncoding:NSUTF8StringEncoding];
    [sock writeData:data withTimeout:-1 tag:0];
}

#pragma mark - AsyncSocketDelegate
-(void)onSocket:(AsyncSocket *)sock didAcceptNewSocket:(AsyncSocket *)newSocket{
    //当前新增的客户端socket
    self.clientSocket = newSocket;//持有这个客户端，否则客户端连接不上
    NSLog(@"有客户端连接了");
    self.textView.text = [self.textView.text stringByAppendingFormat:@"\n%@", @"有客户端连接了"];
    [newSocket readDataWithTimeout:-1 tag:888];//tag对应socket，在接收到信息是可以读取到
}

-(void)onSocketDidDisconnect:(AsyncSocket *)sock{
    NSLog(@"有客户端断开了");
}


/*  接收到数据
 文件过大时，会分段传输，当本次传输数据的长度小于总长度的时候需要累加
 大文件的时候，禁止在内存中堆放，避免内存占用过大
 
 目前处理的是一次接受完的是文字，文件大的分几次接受完成的是图片
 
 */
-(void)onSocket:(AsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag{
    
    NSLog(@"============================");
    NSLog(@"当前接收总长度：%lu  标记tag: %lu", (unsigned long)data.length, tag);
    
    NSInteger currentWriteLength = 0;
    if (_isHeader == NO) {
        _isHeader = YES;
        
        [self deleteFile];//清下本地缓存
        
        //    1~4字节表示类型
        NSInteger type = 0;//一定要给初始值，否则得出的结果是错误的
        [data getBytes:&type range:NSMakeRange(0, 4)];
        NSLog(@"数据类型: %ld", (long)type);
        
        //    5~8字节表示数据总长度
        _fileLength = 0;//一定要给初始值，否则得出的结果是错误的
        [data getBytes:&_fileLength range:NSMakeRange(4, 4)];
        NSLog(@"数据长度: %ld", (long)_fileLength);
        
        NSData* msgData = [data subdataWithRange:NSMakeRange(8, data.length - 8)];
        if (type == 101) {//文字
            NSString* str = [[NSString alloc] initWithData:msgData encoding:NSUTF8StringEncoding];
            NSLog(@"接收到的消息为：%@", str);
            _isHeader = NO;
            self.textView.text = [self.textView.text stringByAppendingFormat:@"\n%@", str];
        }else if (type == 102){//图片
            
        }
        
        currentWriteLength = [self writeToCacheData:msgData tag:tag];
        if (currentWriteLength == _fileLength - 8) {
            
            [self sendMsgSock:sock];
            
            NSString* filePath = [self imagePathTag:tag];
            UIImage* image = [UIImage imageWithContentsOfFile:filePath];
            self.imageView.image = image;
            _isHeader = NO;
        }
    }else{
        currentWriteLength = [self writeToCacheData:data tag:tag];
        if (currentWriteLength == _fileLength - 8) {
            
            [self sendMsgSock:sock];
            
            NSString* filePath = [self imagePathTag:tag];
            UIImage* image = [UIImage imageWithContentsOfFile:filePath];
            self.imageView.image = image;
            _isHeader = NO;
        }
    }
    
    [sock readDataWithTimeout:-1 tag:tag];//等待下一次消息 如果不调用客户端再次发送消息就收不到了
    
    NSLog(@"============================");
}

#pragma mark - write to file
-(NSInteger)writeToCacheData:(NSData*)data tag:(long)tag{
    
    NSLog(@"待写入data长度：%ld", (long)data.length);
    NSString* filePath = [self imagePathTag:tag];
    NSFileHandle* writeFH = [NSFileHandle fileHandleForWritingAtPath:filePath];
    NSInteger currentLength = [writeFH seekToEndOfFile];//光标移到文件尾部，同时查看长度
    NSLog(@"当前文件长度：%ld", (long)currentLength);
    
    [writeFH writeData:data];
    
    //返回当前文件的总长度
    return currentLength + data.length;
}

-(NSString*)imagePathTag:(long)tag{
    
    NSString* filePath = [self filePath:0];
    NSFileManager* fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:filePath]) {
        BOOL hasCreated = [fm createFileAtPath:filePath contents:nil attributes:nil];
        if (hasCreated) {
            NSLog(@"文件创建成功");
        }
    }
    
    return filePath;
}

-(void)deleteFile{
    NSFileManager* fm = [NSFileManager defaultManager];
    NSString* filePath = [self filePath:0];
    if ([fm fileExistsAtPath:filePath]) {
        [fm removeItemAtPath:filePath error:nil];
    }
}

-(NSString*)filePath:(long)tag{
    NSString* docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSString* filePath = [docPath stringByAppendingFormat:@"/%ld.png", tag];
    
    return filePath;
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
