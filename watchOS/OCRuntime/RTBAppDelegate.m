//
//  AppDelegate.m
//  OCRuntime
//
//  Created by Nicolas Seriot on 6/14/13.
//  Copyright (c) 2013 Nicolas Seriot. All rights reserved.
//

#import "RTBAppDelegate.h"

#include <sys/types.h>
#include <sys/sysctl.h>

#import "GCDWebServer.h"
#import "GCDWebServerDataResponse.h"

//#import "RTBClassDisplayVC.h"
#import "RTBRuntimeHeader.h"
#import "RTBClass.h"
#import "RTBProtocol.h"
#import "RTBMyIP.h"
#import "RTBRuntime.h"
//#import "RTBObjectsTVC.h"

#if (! TARGET_OS_IPHONE)
#import <objc/objc-runtime.h>
#else
#import <objc/runtime.h>
#import <objc/message.h>
#endif


@implementation RTBAppDelegate

- (void)useClass:(NSString *)className {
}

- (NSString *)myIPAddress {
    NSString *myIP = [[[RTBMyIP sharedInstance] ipsForInterfaces] objectForKey:@"en0"];
    
#if TARGET_IPHONE_SIMULATOR
    if(!myIP) {
        myIP = [[[RTBMyIP sharedInstance] ipsForInterfaces] objectForKey:@"en1"];
    }
#endif
    
    return myIP;
}

- (GCDWebServerDataResponse *)responseForList {
    NSMutableString *ms = [NSMutableString string];
    
    NSArray *classes = [_allClasses sortedClassStubs];
    [ms appendFormat:@"%@ classes loaded\n\n", @([classes count])];
    for(RTBClass *cs in classes) {
        //if([cs.stubClassname compare:@"S"] == NSOrderedAscending) continue;
        [ms appendFormat:@"<A HREF=\"/classes/%@.h\">%@.h</A>\n", cs.classObjectName, cs.classObjectName];
    }
    
    NSString *html = [self htmlPageWithContents:ms title:@"iOS Runtime Browser - List View"];
    
    return [GCDWebServerDataResponse responseWithHTML:html];
}

- (GCDWebServerDataResponse *)responseForProtocols {
    NSMutableString *ms = [NSMutableString string];
    
    NSArray *protocols = [_allClasses sortedProtocolStubs];
    [ms appendFormat:@"%@ protocols loaded\n\n", @([protocols count])];
    for(RTBProtocol *p in protocols) {
        [ms appendFormat:@"<A HREF=\"/protocols/%@.h\">%@.h</A>\n", p.protocolName, p.protocolName];
    }
    
    NSString *html = [self htmlPageWithContents:ms title:@"iOS Runtime Browser - Protocols"];
    
    return [GCDWebServerDataResponse responseWithHTML:html];
}

+ (NSString *)basePath {
    
    static NSString *basePath = nil;
    
    if(basePath == nil) {
        
        const char* imageNameC = class_getImageName([NSString class]);
        if(imageNameC == NULL) return nil;
        
        NSString *imagePath = [NSString stringWithCString:imageNameC encoding:NSUTF8StringEncoding];
        if(imagePath == nil) return nil;
        
        static NSString *s = @"/System/Library/Frameworks/Foundation.framework/Foundation";
        
        if([s length] > [imagePath length]) return nil;
        NSUInteger i = [imagePath length] - [s length];
        basePath = [imagePath substringToIndex:i];
    }
    
    return basePath;
}

- (GCDWebServerDataResponse *)responseForClassHeaderPath:(NSString *)headerPath {
    NSString *fileName = [headerPath lastPathComponent];
    NSString *className = [fileName stringByDeletingPathExtension];
    
    BOOL displayPropertiesDefaultValues = [[NSUserDefaults standardUserDefaults] boolForKey:@"RTBDisplayPropertiesDefaultValues"];
    NSString *header = [RTBRuntimeHeader headerForClass:NSClassFromString(className) displayPropertiesDefaultValues:displayPropertiesDefaultValues];
    
    if(header == nil) {
        NSLog(@"-- [ERROR] empty header for path %@", headerPath);
        header = @"/* empty header */\n";
    }
    
    return [GCDWebServerDataResponse responseWithText:header];
}

- (GCDWebServerDataResponse *)responseForProtocolHeaderPath:(NSString *)headerPath {
    NSString *fileName = [headerPath lastPathComponent];
    NSString *protocolName = [fileName stringByDeletingPathExtension];
    
    RTBProtocol *p = [RTBProtocol protocolStubWithProtocolName:protocolName];
    NSString *header = [RTBRuntimeHeader headerForProtocol:p];
    
    return [GCDWebServerDataResponse responseWithText:header];
}

- (GCDWebServerDataResponse *)responseForTreeWithFrameworksName:(NSString *)name directory:(NSString *)dir {
    
    if([[name pathExtension] isEqualToString:@"framework"] == NO) return nil;
    
    NSDictionary *allClassesByImagesPath = [[RTBRuntime sharedInstance] allClassStubsByImagePath];
    
    NSString *end = [[name lastPathComponent] stringByDeletingPathExtension];
    NSString *imagePath = [[dir stringByAppendingPathComponent:name] stringByAppendingPathComponent:end];
    
    if([allClassesByImagesPath objectForKey:imagePath] == NO) {
        [[RTBRuntime sharedInstance] emptyCachesAndReadAllRuntimeClasses];
        allClassesByImagesPath = [[RTBRuntime sharedInstance] allClassStubsByImagePath];
        //NSLog(@"-- %@", [allClassesByImagesPath objectForKey:imagePath]);
    }
    
    NSArray *classes = allClassesByImagesPath[imagePath];
    
    /**/
    
    NSMutableString *ms = [NSMutableString string];
    [ms appendFormat:@"%@\n%@ classes\n\n", name, @([classes count])];
    
    NSArray *sortedDylibs = [classes sortedArrayUsingComparator:^NSComparisonResult(NSString *s1, NSString *s2) {
        return [s1 compare:s2];
    }];
    
    for(NSString *s in sortedDylibs) {
        [ms appendFormat:@"<A HREF=\"/tree%@/%@.h\">%@.h</A>\n", name, s, s];
    }
    
    NSString *html = [self htmlPageWithContents:ms title:[name lastPathComponent]];
    
    return [GCDWebServerDataResponse responseWithHTML:html];
}

- (GCDWebServerResponse *)responseForTreeWithDylibWithName:(NSString *)name {
    
    if([[name pathExtension] isEqualToString:@"dylib"] == NO) return nil;
    
    NSDictionary *allClassesByImagesPath = [[RTBRuntime sharedInstance] allClassStubsByImagePath];
    __block NSArray *classes = nil;
    
    [allClassesByImagesPath enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        BOOL isDylib = [[key pathExtension] isEqualToString:@"dylib"];
        if([key rangeOfString:name].location != NSNotFound || (isDylib && [[key lastPathComponent] isEqualToString:[name lastPathComponent]])) {
            classes = obj;
            *stop = YES;
        }
    }];
    
    /**/
    
    NSMutableString *ms = [NSMutableString string];
    [ms appendFormat:@"%@\n%@ dylibs\n\n", name, @([classes count])];
    
    NSArray *sortedDylibs = [classes sortedArrayUsingComparator:^NSComparisonResult(NSString *s1, NSString *s2) {
        return [s1 compare:s2];
    }];
    
    for(NSString *s in sortedDylibs) {
        [ms appendFormat:@"<A HREF=\"/tree%@/%@.h\">%@.h</A>\n", name, s, s];
    }
    
    NSString *html = [self htmlPageWithContents:ms title:[name lastPathComponent]];
    
    return [GCDWebServerDataResponse responseWithHTML:html];
}

- (GCDWebServerResponse *)responseForTreeWithPath:(NSString *)path {
    
    GCDWebServerResponse *response = [self responseForTreeWithFrameworksName:path directory:@"/System/Library/"];
    if(response) return response;
    
    response = [self responseForTreeWithDylibWithName:path];
    if(response) return response;
    
    if([path isEqualToString:@"/"]) {
        
        NSString *s = @"<a href=\"/tree/Frameworks/\">/Frameworks/</a>\n"
        "<a href=\"/tree/PrivateFrameworks/\">/PrivateFrameworks/</a>\n"
        "<a href=\"/tree/lib/\">/lib/</a>\n"
        "<a href=\"/tree/protocols/\">/protocols/</a>\n";
        
        NSString *html = [self htmlPageWithContents:s title:@"iOS Runtime Browser - Tree View"];
        
        return [GCDWebServerDataResponse responseWithHTML:html];
    }
    
    NSMutableString *ms = [NSMutableString string];
    
    if([@[@"/Frameworks/", @"/PrivateFrameworks/"] containsObject:path]) {
        
        NSDictionary *classStubsByImagePath = [[RTBRuntime sharedInstance] allClassStubsByImagePath];
        
        NSMutableArray *files = [NSMutableArray array];
        [classStubsByImagePath enumerateKeysAndObjectsUsingBlock:^(NSString *imagePath, RTBClass *classStub, BOOL *stop) {
            
            NSString *prefix = [NSString stringWithFormat:@"/System/Library%@", path];
            if([imagePath hasPrefix:prefix] == NO) {
                return;
            }
            
            if([[imagePath pathExtension] isEqualToString:@"dylib"]) {
                // eg. /System/Library/Frameworks/AVFoundation.framework/libAVFAudio.dylib
                return;
            }
            
            NSArray *pathComponents = [imagePath pathComponents];
            if([pathComponents count] < 2) return;
            NSString *frameworkName = [pathComponents objectAtIndex:[pathComponents count]-2];
            if([[frameworkName pathExtension] isEqualToString:@"framework"] == NO) return;
            
            [files addObject:frameworkName];
        }];
        [files sortUsingSelector:@selector(compare:)];
        
        [ms appendFormat:@"%@\n%@ frameworks loaded\n\n", path, @([files count])];
        
        for(NSString *fileName in files) {
            [ms appendFormat:@"<a href=\"/tree%@%@\">%@/</a>\n", path, fileName, fileName];
        }
        
    } else if([path isEqualToString:@"/lib/"]) {
        
        NSDictionary *classStubsByImagePath = [[RTBRuntime sharedInstance] allClassStubsByImagePath];
        
        NSMutableArray *files = [NSMutableArray array];
        [classStubsByImagePath enumerateKeysAndObjectsUsingBlock:^(NSString *imagePath, RTBClass *classStub, BOOL *stop) {
            if([[imagePath pathExtension] isEqualToString:@"dylib"] == NO) return;
            [files addObject:[imagePath lastPathComponent]];
        }];
        [files sortUsingSelector:@selector(compare:)];
        
        [ms appendFormat:@"%@\n%@ dylibs\n\n", path, @([files count])];
        
        for(NSString *fileName in files) {
            [ms appendFormat:@"<a href=\"/tree%@%@\">%@/</a>\n", path, fileName, fileName];
        }
    } else if([path isEqualToString:@"/protocols/"]) {
        
        NSMutableArray *sortedProtocolStubs = [[[RTBRuntime sharedInstance] sortedProtocolStubs] mutableCopy];
        
        NSMutableArray *files = [NSMutableArray array];
        [sortedProtocolStubs enumerateObjectsUsingBlock:^(RTBProtocol *p, NSUInteger idx, BOOL *stop) {
            [files addObject:[p protocolName]];
        }];
        
        [ms appendFormat:@"%@\n%@ protocols\n\n", path, @([files count])];
        
        for(NSString *fileName in files) {
            [ms appendFormat:@"<a href=\"/tree%@%@.h\">%@.h</a>\n", path, fileName, fileName];
        }
    }
    NSString *html = [self htmlPageWithContents:ms title:@"iOS Runtime Browser - Tree View"];
    
    return [GCDWebServerDataResponse responseWithHTML:html];
}

- (NSString *)htmlHeader {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"header" ofType:@"html"];
    return [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
}

- (NSString *)htmlFooter {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"footer" ofType:@"html"];
    return [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
}

- (NSString *)htmlPageWithContents:(NSString *)contents title:(NSString *)title {
    NSString *header = [[[self htmlHeader] mutableCopy] stringByReplacingOccurrencesOfString:@"__TITLE__" withString:title];

    NSLog(@"%@", [[@[header, contents, [self htmlFooter]] componentsJoinedByString:@"\n"] debugDescription]);

    return [@[header, contents, [self htmlFooter]] componentsJoinedByString:@"\n"];
}

- (GCDWebServerResponse *)responseForPath:(NSString *)path {
    
    BOOL isProtocol = [path hasPrefix:@"/protocols/"] || [path hasPrefix:@"/tree/protocols/"];
    BOOL isHeaderFile = [path hasSuffix:@".h"];
    
    if(isHeaderFile) {
        if(isProtocol) {
            return [self responseForProtocolHeaderPath:path];
        } else {
            return [self responseForClassHeaderPath:path];
        }
    }
    
    if([path hasPrefix:@"/classes"]) {
        return [self responseForList];
    } else if ([path hasPrefix:@"/tree"]) {
        NSString *subPath = [path substringFromIndex:[@"/tree" length]];
        return [self responseForTreeWithPath:subPath];
    } else if([path hasPrefix:@"/protocols"]) {
        return [self responseForProtocols];
    } else if ([path isEqualToString:@"/"]) {
        NSString *s = [NSString stringWithFormat:
                       @" You can browse the loaded <a href=\"/classes/\">classes</a> and <a href=\"/protocols/\">protocols</a>, or browse everything presented in <a href=\"/tree/\">tree</a>.\n\n"
                       " To retrieve the headers as on <a href=\"https://github.com/nst/iOS-Runtime-Headers\">https://github.com/nst/iOS-Runtime-Headers</a>:\n\n"
                       "     1. iOS OCRuntime > Frameworks tab > Load All\n"
                       "     2. $ wget -r http://%@:10000/tree/\n", [self myIPAddress]];
        
        NSString *html = [self htmlPageWithContents:s title:@"iOS Runtime Browser"];
        
        return [GCDWebServerDataResponse responseWithHTML:html];
    }
    
    return nil;
}

- (void)stopWebServer {
    [_webServer stop];
}

- (void)startWebServer {
    NSDictionary *ips = [[RTBMyIP sharedInstance] ipsForInterfaces];
    BOOL isConnectedThroughWifi = [ips objectForKey:@"en0"] != nil;
    
    if(isConnectedThroughWifi || TARGET_IPHONE_SIMULATOR) {
        
        [GCDWebServer setLogLevel:0];
        
        self.webServer = [[GCDWebServer alloc] init];
        
        __weak typeof(self) weakSelf = self;
        
        [_webServer addDefaultHandlerForMethod:@"GET"
                                  requestClass:[GCDWebServerRequest class]
                                  processBlock:^GCDWebServerResponse *(GCDWebServerRequest* request) {
                                      
                                      __strong typeof(weakSelf) strongSelf = weakSelf;
                                      if(strongSelf == nil) return nil;
                                      
                                      NSLog(@"-- %@ %@", request.method, request.path);
                                      
                                      return [strongSelf responseForPath:request.path];
                                      
                                  }];
        
        BOOL success = [_webServer startWithPort:10000 bonjourName:@"RuntimeBrowser"];
        
        if(success == NO) {
            NSLog(@"Error starting HTTP Server.");

            [self.webServer stop];
            self.webServer = nil;
        } else {
            NSLog(@"Visit %@ in your web browser", _webServer.serverURL);
        }
    } else {
        // TODO: allow USB connection..
        NSLog(@"Not connected through wifi, don't start web server.");
    }
}

- start {
    
    self.allClasses = [RTBRuntime sharedInstance];

  [self startWebServer];

    return nil;
}

- (UInt16)serverPort {
    return [_webServer port];
}

- (void)showHeaderForClassName:(NSString *)className {
}

- (void)showHeaderForProtocol:(RTBProtocol *)protocol {
}

//- (IBAction)dismissModalView:(id)sender {
//	[_tabBarController dismissViewControllerAnimated:YES completion:^{
//        //
//    }];
//}

@end
