#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@interface DexterBridge : NSObject

// Static Methods để gọi dễ dàng từ Swift
+ (void)setSensitivity:(float)value;
+ (float)sensitivity;
+ (void)setSmoothing:(float)value;
+ (float)smoothing;

+ (void)beginStroke:(CGPoint)point timestamp:(double)ts;
+ (void)sampleStroke:(CGPoint)point timestamp:(double)ts;
+ (NSDictionary *)finishStroke:(CGPoint)point timestamp:(double)ts;

+ (BOOL)saveConfig:(NSString *)path;
+ (BOOL)loadConfig:(NSString *)path;

@end

NS_ASSUME_NONNULL_END