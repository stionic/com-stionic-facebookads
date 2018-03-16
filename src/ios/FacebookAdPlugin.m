#import <FBAudienceNetwork/FBAudienceNetwork.h>
#import "UITapGestureRecognizer+Spec.h"
#import "FacebookAdPlugin.h"

@interface FacebookAdPlugin()<FBAdViewDelegate, FBInterstitialAdDelegate, FBNativeAdDelegate, UIGestureRecognizerDelegate>

@property (nonatomic, retain) NSMutableDictionary* nativeads;

- (void) __removeNativeAd:(NSString*)adId;
- (void) fireNativeAdLoadEvent:(FBNativeAd*)nativeAd;
- (void) fireEvent:(NSString *)obj event:(NSString *)eventName withData:(NSString *)jsonStr;

@end


// ------------------------------------------------------------------

@interface UITrackingView : UIView

@end

@implementation UITrackingView
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    // Always ignore the touch event, so that we can scroll the webview beneath.
    // We will inovke GestureRecognizer callback ourselves.
    return nil;
}
@end

// ------------------------------------------------------------------

@interface FlexNativeAd : NSObject

@property (nonatomic, retain) NSString* adId;
@property (nonatomic, retain) FBNativeAd* ad;
@property (nonatomic, retain) UITrackingView* view;
@property (assign) int x,y,w,h;

- (FlexNativeAd*) init;

@end

@implementation FlexNativeAd

- (FlexNativeAd*) init
{
    self.adId = NULL;
    self.ad = NULL;
    self.view = NULL;
    self.x = 0;
    self.y = 0;
    self.w = 0;
    self.h = 0;
    
    return self;
}

@end

// ------------------------------------------------------------------

@implementation FacebookAdPlugin

- (void)pluginInitialize
{
    [super pluginInitialize];
    
    self.nativeads = [[NSMutableDictionary alloc] init];
}

- (void)handleTapOnWebView:(UITapGestureRecognizer *)sender
{
    //NSLog(@"handleTapOnWeb");

    for(id key in self.nativeads) {
        FlexNativeAd* unit = (FlexNativeAd*) [self.nativeads objectForKey:key];
        CGPoint point = [sender locationInView:unit.view];
        if([unit.view pointInside:point withEvent:nil]) {
            NSLog(@"Native Ad view area tapped");

            NSArray* handlers = [unit.view gestureRecognizers];
            for(id handler in handlers) {
                if([handler isKindOfClass:[UITapGestureRecognizer class]]) {
                    UITapGestureRecognizer* tapHandler = (UITapGestureRecognizer*) handler;

                    // Here we call the injected method, defined in "UITapGestureRecognizer+Spec.m"
                    if([tapHandler respondsToSelector:@selector(performTapWithView:andPoint:)]) {
                        [tapHandler performTapWithView:unit.view andPoint:point];
                    }
                }
            }
        }
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
    shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer{
    return YES;
}

- (void)createNativeAd:(CDVInvokedUrlCommand *)command
{
    NSLog(@"createNativeAd");
    
    if([command.arguments count] >= 1) {
        NSString* adId = [command argumentAtIndex:0];
                
        FlexNativeAd* unit = [self.nativeads objectForKey:adId];
        if(unit) {
            if(unit.adId) {
                [self __removeNativeAd:unit.adId];
            }
        }
        
        unit = [[FlexNativeAd alloc] init];
        unit.adId = adId;
        
        CGRect adRect = {{0,0},{0,0}};
        unit.view = [[UITrackingView alloc] initWithFrame:adRect];
        [[self webView] addSubview:unit.view];
        
        // add tap handler to handle tap on webview
        UITapGestureRecognizer *webViewTapped = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapOnWebView:)];
        webViewTapped.numberOfTapsRequired = 1;
        webViewTapped.delegate = self;
        [[self webView] addGestureRecognizer:webViewTapped];
        
        unit.ad = [[FBNativeAd alloc] initWithPlacementID:adId];
        unit.ad.delegate = self;
        
        [self.nativeads setObject:unit forKey:adId];
        
        [unit.ad loadAd];
        
        [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK] callbackId:command.callbackId];
    } else {
        [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"invalid arguments"] callbackId:command.callbackId];
    }
}

- (void) __removeNativeAd:(NSString*)adId
{
    FlexNativeAd* unit = [self.nativeads objectForKey:adId];
    if(unit) {
        [self.nativeads removeObjectForKey:adId];
        
        if(unit.view) {
            CGRect adFrame = {{0,0},{0,0}};
            unit.view.frame = adFrame;
            [unit.view removeFromSuperview];
        }
        
        if(unit.ad) {
            [unit.ad unregisterView];
        }
    }
}

- (void)removeNativeAd:(CDVInvokedUrlCommand *)command
{
    NSLog(@"removeNativeAd");
    
    if([command.arguments count] >= 1) {
        NSString* adId = [command argumentAtIndex:0];
        [self __removeNativeAd:adId];
        
        [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK] callbackId:command.callbackId];
    } else {
        [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"invalid arguments"] callbackId:command.callbackId];
    }
}

- (void)setNativeAdClickArea:(CDVInvokedUrlCommand *)command
{
    NSLog(@"setNativeAdClickArea");
    
    if([command.arguments count] >= 5) {
        NSString* adId = [command argumentAtIndex:0];
        
        FlexNativeAd* unit = [self.nativeads objectForKey:adId];
        if(unit && unit.view) {
            int x = [[command argumentAtIndex:1 withDefault:@"0"] intValue];
            int y = [[command argumentAtIndex:2 withDefault:@"0"] intValue];
            int w = [[command argumentAtIndex:3 withDefault:@"0"] intValue];
            int h = [[command argumentAtIndex:4 withDefault:@"0"] intValue];
            
            CGRect adRect = {{x,y},{w,h}};
            unit.view.frame = adRect;
            
            [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK] callbackId:command.callbackId];
        } else {
            [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"native ad not exists"] callbackId:command.callbackId];
        }
    } else {
        [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"invalid arguments"] callbackId:command.callbackId];
    }
}

/**
 * document.addEventListener('stionic.native.failed', function(data));
 * document.addEventListener('stionic.natie.loaded', function(data));
 * document.addEventListener('stionic.native.clicked', function(data));
 */
- (void)nativeAd:(FBNativeAd *)nativeAd didFailWithError:(NSError *)error
{
    NSString* jsonData = [NSString stringWithFormat:@"{ 'error': '%d', 'message':'%@' }", (int)error.code, [error localizedDescription] ];
    [self fireEvent:@"" event:@"stionic.native.failed" withData:jsonData];
}

- (void)nativeAdDidClick:(FBNativeAd *)nativeAd
{
    [self fireEvent:@"" event:@"stionic.native.clicked" withData:nil];
}

- (void)nativeAdDidLoad:(FBNativeAd *)nativeAd
{
    [self fireNativeAdLoadEvent:nativeAd];
}

- (void) fireNativeAdLoadEvent:(FBNativeAd*)nativeAd
{
    [self.nativeads enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        NSString* adId = (NSString*) key;
        FlexNativeAd* unit = (FlexNativeAd*) obj;
        if(unit && unit.ad == nativeAd) {
            NSString *titleForAd = nativeAd.title;
            NSString *bodyTextForAd = nativeAd.body;
            FBAdImage *coverImage = nativeAd.coverImage;
            FBAdImage *iconForAd = nativeAd.icon;
            NSString *socialContextForAd = nativeAd.socialContext;
            NSString *titleForAdButton = nativeAd.callToAction;
            
            NSMutableDictionary* coverInfo = [[NSMutableDictionary alloc] init];
            [coverInfo setValue:[coverImage.url absoluteString] forKey:@"url"];
            [coverInfo setValue:[NSNumber numberWithInt:coverImage.width] forKey:@"width"];
            [coverInfo setValue:[NSNumber numberWithInt:coverImage.height] forKey:@"height"];
            
            NSMutableDictionary* iconInfo = [[NSMutableDictionary alloc] init];
            [iconInfo setValue:[iconForAd.url absoluteString] forKey:@"url"];
            [iconInfo setValue:[NSNumber numberWithInt:iconForAd.width] forKey:@"width"];
            [iconInfo setValue:[NSNumber numberWithInt:iconForAd.height] forKey:@"height"];
            
            NSMutableDictionary* adRes = [[NSMutableDictionary alloc] init];
            [adRes setValue:coverInfo forKey:@"coverImage"];
            [adRes setValue:iconInfo forKey:@"icon"];
            [adRes setValue:titleForAd forKey:@"title"];
            [adRes setValue:bodyTextForAd forKey:@"body"];
            [adRes setValue:socialContextForAd forKey:@"socialContext"];
            [adRes setValue:titleForAdButton forKey:@"buttonText"];
            
            NSMutableDictionary* json = [[NSMutableDictionary alloc] init];
            [json setValue:adId forKey:@"adId"];
            [json setValue:adRes forKey:@"adRes"];
            
            NSError * err;
            NSData * jsonData = [NSJSONSerialization dataWithJSONObject:json options:0 error:&err];
            NSString * jsonStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            
            [unit.ad registerViewForInteraction:unit.view withViewController:[self viewController]];
            
            [self fireEvent:@"" event:@"stionic.native.loaded" withData:jsonStr];

            *stop = YES;
        }
    }];
}

- (void) fireEvent:(NSString *)obj event:(NSString *)eventName withData:(NSString *)jsonStr
{
    NSString* js;
    if(obj && [obj isEqualToString:@"window"]) {
        js = [NSString stringWithFormat:@"var evt=document.createEvent(\"UIEvents\");evt.initUIEvent(\"%@\",true,false,window,0);window.dispatchEvent(evt);", eventName];
    } else if(jsonStr && [jsonStr length]>0) {
        js = [NSString stringWithFormat:@"javascript:cordova.fireDocumentEvent('%@',%@);", eventName, jsonStr];
    } else {
        js = [NSString stringWithFormat:@"javascript:cordova.fireDocumentEvent('%@');", eventName];
    }
    [self.commandDelegate evalJs:js];
}

- (void)nativeAdWillLogImpression:(FBNativeAd *)nativeAd
{
    // Ad impression
}

@end
