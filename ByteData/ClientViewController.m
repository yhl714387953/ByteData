//
//  ClientViewController.m
//  ByteData
//
//  Created by L's on 2018/6/3.
//  Copyright © 2018年 zuiye. All rights reserved.
//

#import "ClientViewController.h"
#import "AsyncSocket.h"

@interface ClientViewController ()<AsyncSocketDelegate>

/** <#description#> */
@property (nonatomic, strong) AsyncSocket* clientSocket;

@end

@implementation ClientViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //初始化
    self.clientSocket = [[AsyncSocket alloc] initWithDelegate:self];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - IBAction
//开始连接服务器
- (IBAction)startConnect:(UIButton *)sender {
    
    //本机 Internet Protocol 地址 也可设置为本机的实际IP地址如@"192.168.1.116"，也可直接设置为 @"localhost"
#define localIP @"127.0.0.1"
    if (self.clientSocket.isConnected) {
        NSLog(@"当前是连接状态，无需重复连接");
    }else{
        NSError* error;
        [self.clientSocket connectToHost:localIP onPort:8080 withTimeout:-1 error:&error];
    }
}

-(IBAction)sendMsg:(id)sender{
    [self sendMessage];
}

-(IBAction)sendImg:(id)sender{
    [self sendImage];
}

#pragma mark - method
//发送自定义消息
-(void)sendMessage{
    
    NSString* str = @"Hello World!";
    NSData* data = [str dataUsingEncoding:(NSUTF8StringEncoding)];
    NSInteger type = 101;
    
    NSMutableData* mutData = [NSMutableData data];
    //    1~4字节表示类型
    NSData* typeData = [NSData dataWithBytes:&type length:4]; //sizeof(type)
    [mutData appendData:typeData];
    
    //    5~8字节表示数据总长度
    NSInteger bodyLength = data.length + 4 + 4;
    NSData* lengthData = [NSData dataWithBytes:&bodyLength length:4];
    [mutData appendData:lengthData];
    
    //    再将文字追加上
    [mutData appendData:data];
    
    [self.clientSocket writeData:mutData withTimeout:-1 tag:333];
}

-(void)sendImage{
    
    NSString* url = [[NSBundle mainBundle] pathForResource:@"xcm" ofType:@"jpeg"];
    NSData* data = [NSData dataWithContentsOfFile:url];
    NSInteger type = 102;
    
    NSMutableData* mutData = [NSMutableData data];
    //    1~4字节表示类型
    NSData* typeData = [NSData dataWithBytes:&type length:4]; //sizeof(type)
    [mutData appendData:typeData];
    
    //    5~8字节表示数据总长度
    NSInteger bodyLength = data.length + 4 + 4;
    NSData* lengthData = [NSData dataWithBytes:&bodyLength length:4];
    [mutData appendData:lengthData];
    
    //    再将图片追加上
    [mutData appendData:data];
    
    [self.clientSocket writeData:mutData withTimeout:-1 tag:0];
}

#pragma mark - AsyncSocketDelegate
-(void)onSocket:(AsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port{
    NSLog(@"服务器连接成功");//链接成功后，开始接收消息
    [self.clientSocket readDataWithTimeout:-1 tag:0];
}

-(void)onSocketDidDisconnect:(AsyncSocket *)sock{
    NSLog(@"失去连接");
}

-(void)onSocket:(AsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag{
    NSString* msg = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"接收到消息:%@", msg);
    [sock readDataWithTimeout:-1 tag:0];//服务器你可以给我发送消息了
}

-(void)onSocket:(AsyncSocket *)sock didWriteDataWithTag:(long)tag{
    NSLog(@"消息发送成功tag：%ld", tag);
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
