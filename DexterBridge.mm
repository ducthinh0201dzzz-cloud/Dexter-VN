#import "DexterBridge.h"
#include "Core.hpp"

@implementation DexterBridge

static DexterVN::Core* _core = nullptr;

+ (void)initialize {
    if (self == [DexterBridge class]) {
        _core = new DexterVN::Core();
    }
}

+ (void)setSensitivity:(float)value { _core->SetSensitivity(value); }
+ (float)sensitivity { return _core->GetSensitivity(); }
+ (void)setSmoothing:(float)value { _core->SetSmoothing(value); }
+ (float)smoothing { return _core->GetSmoothing(); }

+ (void)beginStroke:(CGPoint)point timestamp:(double)ts {
    _core->stroke.Begin(point.x, point.y, ts);
}

+ (void)sampleStroke:(CGPoint)point timestamp:(double)ts {
    _core->stroke.Sample(point.x, point.y, ts);
}

+ (NSDictionary *)finishStroke:(CGPoint)point timestamp:(double)ts {
    auto res = _core->stroke.Finish(point.x, point.y, ts);
    return @{
        @"distance": @(res[0]),
        @"duration": @(res[1]),
        @"straightness": @(res[2]),
        @"stability": @(res[3]),
        @"speed": @(res[4])
    };
}

+ (BOOL)saveConfig:(NSString *)path {
    return _core->Save([path UTF8String]);
}

+ (BOOL)loadConfig:(NSString *)path {
    return _core->Load([path UTF8String]);
}

@end