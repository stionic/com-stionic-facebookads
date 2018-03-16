#import <Cordova/CDV.h>
#import <Foundation/Foundation.h>

@interface FacebookAdPlugin : CDVPlugin {}

- (void)pluginInitialize;

- (void)createNativeAd:(CDVInvokedUrlCommand *)command;
- (void)removeNativeAd:(CDVInvokedUrlCommand *)command;
- (void)setNativeAdClickArea:(CDVInvokedUrlCommand *)command;

@end
