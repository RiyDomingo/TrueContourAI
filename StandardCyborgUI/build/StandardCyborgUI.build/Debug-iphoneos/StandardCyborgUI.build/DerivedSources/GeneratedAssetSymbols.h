#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The "Dismiss" asset catalog image resource.
static NSString * const ACImageNameDismiss AC_SWIFT_PRIVATE = @"Dismiss";

/// The "FlipCamera" asset catalog image resource.
static NSString * const ACImageNameFlipCamera AC_SWIFT_PRIVATE = @"FlipCamera";

/// The "ShutterButton" asset catalog image resource.
static NSString * const ACImageNameShutterButton AC_SWIFT_PRIVATE = @"ShutterButton";

/// The "ShutterButton-Recording" asset catalog image resource.
static NSString * const ACImageNameShutterButtonRecording AC_SWIFT_PRIVATE = @"ShutterButton-Recording";

/// The "ShutterButton-Selected" asset catalog image resource.
static NSString * const ACImageNameShutterButtonSelected AC_SWIFT_PRIVATE = @"ShutterButton-Selected";

/// The "StandardCyborgLogoText" asset catalog image resource.
static NSString * const ACImageNameStandardCyborgLogoText AC_SWIFT_PRIVATE = @"StandardCyborgLogoText";

/// The "matcap" asset catalog image resource.
static NSString * const ACImageNameMatcap AC_SWIFT_PRIVATE = @"matcap";

#undef AC_SWIFT_PRIVATE
