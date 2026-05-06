#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// Runtime branding revert for sideloaded Twitter/X builds.
// This file intentionally does not bundle Twitter-owned artwork.
// If you want official-looking artwork, provide your own local PNG files in:
//   layout/Library/Application Support/BHT/BHTwitter.bundle/Branding/
//     twitter_logo.png
//     twitter_app_icon.png
//     twitter_launch_logo.png
//     twitter_tab_logo.png

static NSString * const BHBrandingDefaultsKey = @"bh_restore_twitter_branding";
static NSInteger const BHBrandingSplashTag = 4377001;

static BOOL BHBrandingRevertEnabled(void) {
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:BHBrandingDefaultsKey];
    return value == nil ? YES : [value boolValue];
}

static UIColor *BHBrandingTwitterBlue(void) {
    return [UIColor colorWithRed:29.0/255.0 green:161.0/255.0 blue:242.0/255.0 alpha:1.0];
}

static NSString *BHBrandingRevertedString(NSString *string) {
    if (!BHBrandingRevertEnabled() || ![string isKindOfClass:NSString.class] || string.length == 0) {
        return string;
    }

    static NSDictionary<NSString *, NSString *> *exactMap;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        exactMap = @{
            // Brand
            @"X": @"Twitter",
            @"𝕏": @"Twitter",
            @"X app": @"Twitter app",
            @"X App": @"Twitter App",
            @"X for iPhone": @"Twitter for iPhone",
            @"X for iPad": @"Twitter for iPad",
            @"Open X": @"Open Twitter",
            @"Share via X": @"Share via Twitter",
            @"Welcome to X": @"Welcome to Twitter",
            @"What’s happening on X": @"What’s happening on Twitter",
            @"What's happening on X": @"What's happening on Twitter",

            // Tweet wording
            @"Post": @"Tweet",
            @"Posts": @"Tweets",
            @"post": @"tweet",
            @"posts": @"tweets",
            @"Repost": @"Retweet",
            @"Reposts": @"Retweets",
            @"repost": @"retweet",
            @"reposts": @"retweets",
            @"Quote post": @"Quote Tweet",
            @"Quote Post": @"Quote Tweet",
            @"Post your reply": @"Tweet your reply",
            @"Create your post": @"Compose new Tweet",
            @"Create post": @"Compose Tweet",
            @"New post": @"New Tweet",
            @"Your post was sent": @"Your Tweet was sent",
            @"Your Post was sent": @"Your Tweet was sent",
            @"Undo Post": @"Undo Tweet",
            @"Undo post": @"Undo Tweet",

            // Premium wording
            @"Premium": @"Twitter Blue",
            @"X Premium": @"Twitter Blue",
            @"Subscribe to Premium": @"Subscribe to Twitter Blue",
            @"Premium+": @"Twitter Blue+",
            @"X Premium+": @"Twitter Blue+",

            // Japanese brand/tweet wording
            @"Xへようこそ": @"Twitterへようこそ",
            @"Xアプリ": @"Twitterアプリ",
            @"Xで開く": @"Twitterで開く",
            @"Xで共有": @"Twitterで共有",
            @"ポスト": @"ツイート",
            @"ポストする": @"ツイートする",
            @"新しいポスト": @"新しいツイート",
            @"ポストを作成": @"ツイートを作成",
            @"返信をポスト": @"返信をツイート",
            @"リポスト": @"リツイート",
            @"引用ポスト": @"引用ツイート",
            @"ポストを取り消す": @"ツイートを取り消す",
            @"Xプレミアム": @"Twitter Blue",
            @"プレミアム": @"Twitter Blue"
        };
    });

    NSString *exact = exactMap[string];
    if (exact != nil) {
        return exact;
    }

    // Conservative in-sentence replacements. Keep this limited to avoid changing unrelated text.
    NSString *result = [string copy];
    if (result.length <= 180) {
        NSDictionary<NSString *, NSString *> *containsMap = @{
            @"X Premium": @"Twitter Blue",
            @"Xプレミアム": @"Twitter Blue",
            @"Quote post": @"Quote Tweet",
            @"Quote Post": @"Quote Tweet",
            @"Create post": @"Compose Tweet",
            @"New post": @"New Tweet",
            @"ポスト": @"ツイート",
            @"リポスト": @"リツイート",
            @"引用ツイートする": @"引用ツイートする"
        };

        [containsMap enumerateKeysAndObjectsUsingBlock:^(NSString *target, NSString *replacement, BOOL *stop) {
            result = [result stringByReplacingOccurrencesOfString:target withString:replacement];
        }];
    }

    return result;
}

static void BHSwizzleInstanceMethod(Class cls, SEL originalSelector, SEL swizzledSelector) {
    Method originalMethod = class_getInstanceMethod(cls, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(cls, swizzledSelector);

    if (!cls || !originalMethod || !swizzledMethod) {
        return;
    }

    BOOL didAddMethod = class_addMethod(cls,
                                        originalSelector,
                                        method_getImplementation(swizzledMethod),
                                        method_getTypeEncoding(swizzledMethod));

    if (didAddMethod) {
        class_replaceMethod(cls,
                            swizzledSelector,
                            method_getImplementation(originalMethod),
                            method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}

static void BHSwizzleClassMethod(Class cls, SEL originalSelector, SEL swizzledSelector) {
    Class metaClass = object_getClass(cls);
    Method originalMethod = class_getClassMethod(cls, originalSelector);
    Method swizzledMethod = class_getClassMethod(cls, swizzledSelector);

    if (!metaClass || !originalMethod || !swizzledMethod) {
        return;
    }

    BOOL didAddMethod = class_addMethod(metaClass,
                                        originalSelector,
                                        method_getImplementation(swizzledMethod),
                                        method_getTypeEncoding(swizzledMethod));

    if (didAddMethod) {
        class_replaceMethod(metaClass,
                            swizzledSelector,
                            method_getImplementation(originalMethod),
                            method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}

static NSArray<NSString *> *BHBrandingBundleSearchRoots(void) {
    NSMutableArray<NSString *> *roots = [NSMutableArray array];

    NSString *mainBundlePath = [[NSBundle mainBundle] pathForResource:@"BHTwitter" ofType:@"bundle"];
    if (mainBundlePath.length > 0) {
        [roots addObject:[mainBundlePath stringByAppendingPathComponent:@"Branding"]];
    }

    [roots addObject:@"/Library/Application Support/BHT/BHTwitter.bundle/Branding"];
    [roots addObject:@"/var/jb/Library/Application Support/BHT/BHTwitter.bundle/Branding"];

    return roots;
}

static UIImage *BHBrandingImageFromBundle(NSString *fileName) {
    if (!BHBrandingRevertEnabled() || fileName.length == 0) {
        return nil;
    }

    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *root in BHBrandingBundleSearchRoots()) {
        NSString *path = [root stringByAppendingPathComponent:fileName];
        if ([fm fileExistsAtPath:path]) {
            UIImage *image = [UIImage imageWithContentsOfFile:path];
            if (image != nil) {
                return image;
            }
        }
    }

    return nil;
}

static UIImage *BHBrandingGeneratedImage(CGSize size, NSString *text, BOOL roundedIcon) {
    CGFloat width = MAX(size.width, 96.0);
    CGFloat height = MAX(size.height, 96.0);
    CGRect rect = CGRectMake(0, 0, width, height);

    UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
    format.scale = UIScreen.mainScreen.scale;
    format.opaque = roundedIcon;

    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:rect.size format:format];
    UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        CGContextRef ctx = context.CGContext;

        if (roundedIcon) {
            UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:width * 0.22];
            [BHBrandingTwitterBlue() setFill];
            [path fill];
        } else {
            CGContextClearRect(ctx, rect);
        }

        NSString *drawText = text.length > 0 ? text : @"Twitter";
        UIFont *font;
        if ([drawText isEqualToString:@"t"]) {
            font = [UIFont boldSystemFontOfSize:width * 0.68];
        } else {
            font = [UIFont boldSystemFontOfSize:MIN(width * 0.22, 42.0)];
        }

        NSDictionary *attrs = @{
            NSFontAttributeName: font,
            NSForegroundColorAttributeName: UIColor.whiteColor
        };

        CGSize textSize = [drawText sizeWithAttributes:attrs];
        CGRect textRect = CGRectMake((width - textSize.width) / 2.0,
                                     (height - textSize.height) / 2.0,
                                     textSize.width,
                                     textSize.height);
        [drawText drawInRect:textRect withAttributes:attrs];
    }];

    return image;
}

static BOOL BHBrandingImageNameLooksLikeXBrand(NSString *name) {
    if (![name isKindOfClass:NSString.class] || name.length == 0) {
        return NO;
    }

    NSString *lower = name.lowercaseString;
    NSArray<NSString *> *exactNames = @[@"x", @"x_logo", @"xlogo", @"x-icon", @"x_icon", @"twitter_x", @"twitterx"];
    if ([exactNames containsObject:lower]) {
        return YES;
    }

    NSArray<NSString *> *tokens = @[
        @"x_logo", @"xlogo", @"x-brand", @"x_brand", @"brand_x",
        @"twitter_x", @"twitterx", @"x_mark", @"xmark_logo",
        @"premium_logo", @"verified_org_logo"
    ];

    for (NSString *token in tokens) {
        if ([lower containsString:token]) {
            return YES;
        }
    }

    return NO;
}

static BOOL BHBrandingImageNameLooksLikeAppIcon(NSString *name) {
    if (![name isKindOfClass:NSString.class] || name.length == 0) {
        return NO;
    }

    NSString *lower = name.lowercaseString;
    if ([lower containsString:@"appicon"] || [lower containsString:@"app_icon"] || [lower containsString:@"alternate_icon"]) {
        return YES;
    }

    return NO;
}

static UIImage *BHBrandingReplacementImageForName(NSString *name, CGSize preferredSize) {
    if (!BHBrandingRevertEnabled()) {
        return nil;
    }

    if (BHBrandingImageNameLooksLikeAppIcon(name)) {
        UIImage *icon = BHBrandingImageFromBundle(@"twitter_app_icon.png");
        return icon ?: BHBrandingGeneratedImage(preferredSize, @"t", YES);
    }

    if (BHBrandingImageNameLooksLikeXBrand(name)) {
        UIImage *logo = BHBrandingImageFromBundle(@"twitter_logo.png");
        return logo ?: BHBrandingGeneratedImage(preferredSize, @"Twitter", NO);
    }

    return nil;
}

static UIWindow *BHBrandingActiveWindow(void) {
    UIWindow *keyWindow = UIApplication.sharedApplication.keyWindow;
    if (keyWindow != nil) {
        return keyWindow;
    }

    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) {
                continue;
            }
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            for (UIWindow *window in windowScene.windows) {
                if (window.isKeyWindow) {
                    return window;
                }
            }
        }
    }

    return UIApplication.sharedApplication.windows.firstObject;
}

static void BHBrandingShowSplash(void) {
    if (!BHBrandingRevertEnabled()) {
        return;
    }

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIWindow *window = BHBrandingActiveWindow();
            if (window == nil || [window viewWithTag:BHBrandingSplashTag] != nil) {
                return;
            }

            UIView *splash = [[UIView alloc] initWithFrame:window.bounds];
            splash.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            splash.backgroundColor = BHBrandingTwitterBlue();
            splash.tag = BHBrandingSplashTag;
            splash.userInteractionEnabled = NO;

            UIImage *logo = BHBrandingImageFromBundle(@"twitter_launch_logo.png");
            if (logo == nil) {
                logo = BHBrandingImageFromBundle(@"twitter_logo.png");
            }
            if (logo == nil) {
                logo = BHBrandingGeneratedImage(CGSizeMake(260, 100), @"Twitter", NO);
            }

            UIImageView *logoView = [[UIImageView alloc] initWithImage:logo];
            logoView.contentMode = UIViewContentModeScaleAspectFit;
            logoView.translatesAutoresizingMaskIntoConstraints = NO;
            [splash addSubview:logoView];

            CGFloat logoWidth = MIN(CGRectGetWidth(window.bounds) * 0.56, 280.0);
            [NSLayoutConstraint activateConstraints:@[
                [logoView.centerXAnchor constraintEqualToAnchor:splash.centerXAnchor],
                [logoView.centerYAnchor constraintEqualToAnchor:splash.centerYAnchor],
                [logoView.widthAnchor constraintEqualToConstant:logoWidth],
                [logoView.heightAnchor constraintEqualToConstant:logoWidth * 0.42]
            ]];

            [window addSubview:splash];

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [UIView animateWithDuration:0.28 animations:^{
                    splash.alpha = 0.0;
                } completion:^(BOOL finished) {
                    [splash removeFromSuperview];
                }];
            });
        });
    });
}

@implementation NSBundle (BHBrandingRevert)

- (NSString *)bh_branding_localizedStringForKey:(NSString *)key value:(NSString *)value table:(NSString *)tableName {
    NSString *localized = [self bh_branding_localizedStringForKey:key value:value table:tableName];
    return BHBrandingRevertedString(localized);
}

- (id)bh_branding_objectForInfoDictionaryKey:(NSString *)key {
    id value = [self bh_branding_objectForInfoDictionaryKey:key];

    if (BHBrandingRevertEnabled() && [key isKindOfClass:NSString.class]) {
        if ([key isEqualToString:@"CFBundleDisplayName"] || [key isEqualToString:@"CFBundleName"]) {
            return @"Twitter";
        }
    }

    return value;
}

@end

@implementation UIImage (BHBrandingRevert)

+ (UIImage *)bh_branding_imageNamed:(NSString *)name {
    UIImage *replacement = BHBrandingReplacementImageForName(name, CGSizeMake(160, 160));
    if (replacement != nil) {
        return replacement;
    }
    return [self bh_branding_imageNamed:name];
}

+ (UIImage *)bh_branding_imageNamed:(NSString *)name inBundle:(NSBundle *)bundle compatibleWithTraitCollection:(UITraitCollection *)traitCollection {
    UIImage *replacement = BHBrandingReplacementImageForName(name, CGSizeMake(160, 160));
    if (replacement != nil) {
        return replacement;
    }
    return [self bh_branding_imageNamed:name inBundle:bundle compatibleWithTraitCollection:traitCollection];
}

+ (UIImage *)bh_branding_imageWithContentsOfFile:(NSString *)path {
    NSString *lastPath = path.lastPathComponent ?: @"";
    UIImage *replacement = BHBrandingReplacementImageForName(lastPath, CGSizeMake(160, 160));
    if (replacement != nil) {
        return replacement;
    }
    return [self bh_branding_imageWithContentsOfFile:path];
}

@end

@implementation UILabel (BHBrandingRevert)

- (void)bh_branding_setText:(NSString *)text {
    [self bh_branding_setText:BHBrandingRevertedString(text)];
}

@end

@implementation UIButton (BHBrandingRevert)

- (void)bh_branding_setTitle:(NSString *)title forState:(UIControlState)state {
    [self bh_branding_setTitle:BHBrandingRevertedString(title) forState:state];
}

@end

@implementation UIViewController (BHBrandingRevert)

- (void)bh_branding_setTitle:(NSString *)title {
    [self bh_branding_setTitle:BHBrandingRevertedString(title)];
}

@end

@implementation UINavigationItem (BHBrandingRevert)

- (void)bh_branding_setTitle:(NSString *)title {
    [self bh_branding_setTitle:BHBrandingRevertedString(title)];
}

@end

@implementation UITextField (BHBrandingRevert)

- (void)bh_branding_setPlaceholder:(NSString *)placeholder {
    [self bh_branding_setPlaceholder:BHBrandingRevertedString(placeholder)];
}

@end

@implementation UITextView (BHBrandingRevert)

- (void)bh_branding_setText:(NSString *)text {
    [self bh_branding_setText:BHBrandingRevertedString(text)];
}

@end

@implementation UISearchBar (BHBrandingRevert)

- (void)bh_branding_setPlaceholder:(NSString *)placeholder {
    [self bh_branding_setPlaceholder:BHBrandingRevertedString(placeholder)];
}

@end

__attribute__((constructor))
static void BHInstallBrandingRevert(void) {
    @autoreleasepool {
        BHSwizzleInstanceMethod(NSBundle.class,
                                @selector(localizedStringForKey:value:table:),
                                @selector(bh_branding_localizedStringForKey:value:table:));

        BHSwizzleInstanceMethod(NSBundle.class,
                                @selector(objectForInfoDictionaryKey:),
                                @selector(bh_branding_objectForInfoDictionaryKey:));

        BHSwizzleClassMethod(UIImage.class,
                             @selector(imageNamed:),
                             @selector(bh_branding_imageNamed:));

        BHSwizzleClassMethod(UIImage.class,
                             @selector(imageNamed:inBundle:compatibleWithTraitCollection:),
                             @selector(bh_branding_imageNamed:inBundle:compatibleWithTraitCollection:));

        BHSwizzleClassMethod(UIImage.class,
                             @selector(imageWithContentsOfFile:),
                             @selector(bh_branding_imageWithContentsOfFile:));

        BHSwizzleInstanceMethod(UILabel.class,
                                @selector(setText:),
                                @selector(bh_branding_setText:));

        BHSwizzleInstanceMethod(UIButton.class,
                                @selector(setTitle:forState:),
                                @selector(bh_branding_setTitle:forState:));

        BHSwizzleInstanceMethod(UIViewController.class,
                                @selector(setTitle:),
                                @selector(bh_branding_setTitle:));

        BHSwizzleInstanceMethod(UINavigationItem.class,
                                @selector(setTitle:),
                                @selector(bh_branding_setTitle:));

        BHSwizzleInstanceMethod(UITextField.class,
                                @selector(setPlaceholder:),
                                @selector(bh_branding_setPlaceholder:));

        BHSwizzleInstanceMethod(UITextView.class,
                                @selector(setText:),
                                @selector(bh_branding_setText:));

        BHSwizzleInstanceMethod(UISearchBar.class,
                                @selector(setPlaceholder:),
                                @selector(bh_branding_setPlaceholder:));

        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
            BHBrandingShowSplash();
        }];
    }
}
