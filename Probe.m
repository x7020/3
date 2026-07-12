#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

static UIButton *gProbeButton = nil;

static UIWindow *ProbeKeyWindow(void) {
    UIApplication *app = UIApplication.sharedApplication;
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in app.connectedScenes) {
            if (scene.activationState != UISceneActivationStateForegroundActive) continue;
            if (![scene isKindOfClass:UIWindowScene.class]) continue;
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            for (UIWindow *window in windowScene.windows) {
                if (window.isKeyWindow) return window;
            }
            for (UIWindow *window in windowScene.windows) {
                if (!window.hidden && window.alpha > 0.01) return window;
            }
        }
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    for (UIWindow *window in app.windows) {
        if (window.isKeyWindow) return window;
    }
    return app.windows.firstObject;
#pragma clang diagnostic pop
}

static UIViewController *ProbeTopController(UIViewController *root) {
    if (!root) return nil;
    UIViewController *presented = root.presentedViewController;
    if (presented && !presented.isBeingDismissed) {
        return ProbeTopController(presented);
    }
    if ([root isKindOfClass:UINavigationController.class]) {
        return ProbeTopController(((UINavigationController *)root).visibleViewController);
    }
    if ([root isKindOfClass:UITabBarController.class]) {
        return ProbeTopController(((UITabBarController *)root).selectedViewController);
    }
    for (UIViewController *child in [root.childViewControllers reverseObjectEnumerator]) {
        if (child.viewIfLoaded.window) return ProbeTopController(child);
    }
    return root;
}

static NSString *ProbeSafeString(id value) {
    if (!value) return @"";
    NSString *text = [value description] ?: @"";
    text = [text stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
    if (text.length > 180) text = [[text substringToIndex:180] stringByAppendingString:@"…"];
    return text;
}

static void ProbeDumpView(UIView *view, NSMutableString *out, NSInteger depth) {
    if (!view || depth > 80) return;
    NSMutableString *indent = [NSMutableString string];
    for (NSInteger i = 0; i < depth; i++) [indent appendString:@"  "];

    CGRect frame = view.frame;
    NSString *label = ProbeSafeString(view.accessibilityLabel);
    NSString *value = ProbeSafeString(view.accessibilityValue);
    NSString *identifier = ProbeSafeString(view.accessibilityIdentifier);
    NSString *text = @"";
    if ([view isKindOfClass:UILabel.class]) text = ProbeSafeString(((UILabel *)view).text);
    else if ([view isKindOfClass:UIButton.class]) text = ProbeSafeString([((UIButton *)view) titleForState:UIControlStateNormal]);
    else if ([view isKindOfClass:UITextView.class]) text = ProbeSafeString(((UITextView *)view).text);
    else if ([view isKindOfClass:UITextField.class]) text = ProbeSafeString(((UITextField *)view).text);

    [out appendFormat:@"%@%@ frame=(%.1f,%.1f,%.1f,%.1f) hidden=%d alpha=%.2f UI=%d",
     indent, NSStringFromClass(view.class), frame.origin.x, frame.origin.y,
     frame.size.width, frame.size.height, view.hidden, view.alpha,
     view.userInteractionEnabled];
    if (label.length) [out appendFormat:@" label=\"%@\"", label];
    if (value.length) [out appendFormat:@" value=\"%@\"", value];
    if (identifier.length) [out appendFormat:@" id=\"%@\"", identifier];
    if (text.length) [out appendFormat:@" text=\"%@\"", text];
    [out appendString:@"\n"];

    for (UIView *subview in view.subviews) {
        if (subview == gProbeButton) continue;
        ProbeDumpView(subview, out, depth + 1);
    }
}

static NSString *ProbeBuildDump(void) {
    UIWindow *window = ProbeKeyWindow();
    UIViewController *top = ProbeTopController(window.rootViewController);
    NSMutableString *out = [NSMutableString string];
    [out appendFormat:@"Bundle: %@\n", NSBundle.mainBundle.bundleIdentifier ?: @""];
    [out appendFormat:@"Version: %@ (%@)\n",
     [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"",
     [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @""];
    [out appendFormat:@"TopController: %@\n", top ? NSStringFromClass(top.class) : @"(nil)"];
    [out appendFormat:@"RootController: %@\n", window.rootViewController ? NSStringFromClass(window.rootViewController.class) : @"(nil)"];
    [out appendFormat:@"Window: %@ frame=%@\n\n", NSStringFromClass(window.class), NSStringFromCGRect(window.frame)];
    ProbeDumpView(window, out, 0);
    return out;
}

static void ProbeShowAlert(NSString *title, NSString *message) {
    UIWindow *window = ProbeKeyWindow();
    UIViewController *top = ProbeTopController(window.rootViewController);
    if (!top) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [top presentViewController:alert animated:YES completion:nil];
}

static void ProbeCopyDump(void) {
    NSString *dump = ProbeBuildDump();
    UIPasteboard.generalPasteboard.string = dump;
    ProbeShowAlert(@"页面结构已复制", [NSString stringWithFormat:@"共 %lu 个字符。打开备忘录粘贴后，把文本发回来。", (unsigned long)dump.length]);
}

static void ProbeShowController(void) {
    UIWindow *window = ProbeKeyWindow();
    UIViewController *top = ProbeTopController(window.rootViewController);
    NSString *message = [NSString stringWithFormat:@"当前控制器：\n%@\n\nBundle：\n%@",
                         top ? NSStringFromClass(top.class) : @"(nil)",
                         NSBundle.mainBundle.bundleIdentifier ?: @""];
    ProbeShowAlert(@"探针已加载", message);
}

@interface ProductProbeTarget : NSObject
+ (void)buttonTapped;
@end

@implementation ProductProbeTarget
+ (void)buttonTapped {
    UIWindow *window = ProbeKeyWindow();
    UIViewController *top = ProbeTopController(window.rootViewController);
    if (!top) return;

    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"商品页面探针"
                                                                    message:@"先停留在商品列表页，点“复制页面结构”；进入详情页后再复制一次。"
                                                             preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:@"复制页面结构" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        ProbeCopyDump();
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"查看当前控制器" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
        ProbeShowController();
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"关闭" style:UIAlertActionStyleCancel handler:nil]];

    if (sheet.popoverPresentationController) {
        sheet.popoverPresentationController.sourceView = gProbeButton ?: window;
        sheet.popoverPresentationController.sourceRect = gProbeButton ? gProbeButton.bounds : CGRectMake(20, 20, 1, 1);
    }
    [top presentViewController:sheet animated:YES completion:nil];
}
@end

static void ProbeInstallButton(void) {
    if (gProbeButton.superview) return;
    UIWindow *window = ProbeKeyWindow();
    if (!window) return;

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.frame = CGRectMake(10, 150, 58, 34);
    button.layer.cornerRadius = 10.0;
    button.layer.borderWidth = 1.0;
    button.layer.borderColor = UIColor.whiteColor.CGColor;
    button.backgroundColor = [UIColor colorWithWhite:0.05 alpha:0.82];
    [button setTitle:@"探针" forState:UIControlStateNormal];
    [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont boldSystemFontOfSize:14.0];
    [button addTarget:ProductProbeTarget.class action:@selector(buttonTapped) forControlEvents:UIControlEventTouchUpInside];
    button.accessibilityIdentifier = @"ProductProbeButton";
    gProbeButton = button;
    [window addSubview:button];
    [window bringSubviewToFront:button];
}

static void ProbeInstallButtonWithRetry(NSInteger attempt) {
    ProbeInstallButton();
    if (!gProbeButton.superview && attempt < 20) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            ProbeInstallButtonWithRetry(attempt + 1);
        });
    }
}

__attribute__((constructor))
static void ProductProbeInit(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            ProbeInstallButtonWithRetry(1);
        });
    });
}
