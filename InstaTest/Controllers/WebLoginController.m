//
//  SBInstagramWevViewController.m
//  instagram
//
//  Created by Santiago Bustamante on 8/28/13.
//  Copyright (c) 2013 Pineapple Inc. All rights reserved.
//

#import "WebLoginController.h"

#define SB_SYSTEM_VERSION_GREATER_THAN(v) ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedDescending)

@interface WebLoginController ()

@end

@implementation WebLoginController

+ (id) webViewWithUrl:(NSString *)url andSuccessBlock:(void (^)(NSString *token, UIViewController *viewController))block{
    WebLoginController *instance = [[WebLoginController alloc] initWithNibName:@"WebLoginController" bundle:nil];
    instance.url = url;
    instance.block = block;
    return instance;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = @"Instagram Login";
    
    NSURL *urlns = [NSURL URLWithString:self.url];
    NSURLRequest *request = [NSURLRequest requestWithURL:urlns];
    [self.webView loadRequest:request];
    
    [self.webView.subviews enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if ([obj isKindOfClass:[UIScrollView class]]) {
            [((UIScrollView *)obj) setBounces:NO];
        }
    }];
    
    if ([UIApplication sharedApplication].statusBarStyle == UIStatusBarStyleDefault && ![UIApplication sharedApplication].statusBarHidden && SB_SYSTEM_VERSION_GREATER_THAN(@"6.9")) {
        CGRect frame = self.webView.frame;
        frame.origin.y += 20;
        self.webView.frame = frame;
    }
}

- (void)webViewDidFinishLoad:(UIWebView *)webView{
    [self.activityIndicator stopAnimating];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    
    if ([request.URL.absoluteString hasPrefix:[[InstagramEngine sharedEngine] appRedirectURL]]) {
        NSString *token = [[request URL] fragment];
        NSArray *arr = [token componentsSeparatedByString:@"="];
        token = [arr objectAtIndex:1];
        
        NSRange range = [token rangeOfString:@"."];
        NSString *_id = [token substringToIndex:range.location];
        [[NSUserDefaults standardUserDefaults] setObject:_id forKey:@"user_id"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        self.block(token,self);
        self.block = nil;
        return NO;
    }
    
    return YES;
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
