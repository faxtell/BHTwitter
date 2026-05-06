#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// Runtime branding revert for sideloaded Twitter/X builds.
// This intentionally avoids bundling Twitter-owned assets; it focuses on safe text/title reverts.

static BOOL BHBrandingRevertEnabled(void) {
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:@"bh_restore_twitter_branding"];
    return value == nil ? YES : [value boolValue];
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
    if (result.length <= 160) {
        NSDictionary<NSString *, NSString *> *containsMap = @{
            @"X Premium": @"Twitter Blue",
            @"Xプレミアム": @"Twitter Blue",
            @"Quote post": @"Quote Tweet",
            @"Quote Post": @"Quote Tweet",
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

__attribute__((constructor))
static void BHInstallBrandingRevert(void) {
    @autoreleasepool {
        BHSwizzleInstanceMethod(NSBundle.class,
                                @selector(localizedStringForKey:value:table:),
                                @selector(bh_branding_localizedStringForKey:value:table:));

        BHSwizzleInstanceMethod(NSBundle.class,
                                @selector(objectForInfoDictionaryKey:),
                                @selector(bh_branding_objectForInfoDictionaryKey:));

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
    }
}
