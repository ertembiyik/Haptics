import Foundation

enum Swizzler {

    static func swizzleSelector(classToSwizzle: AnyClass,
                                originalSelector: Selector,
                                swizzledSelector: Selector) {
        guard let originalMethod = class_getInstanceMethod(classToSwizzle, originalSelector),
              let swizzledMethod = class_getInstanceMethod(classToSwizzle, swizzledSelector) else {
            return
        }

        let didAddMethod = class_addMethod(classToSwizzle,
                                           originalSelector,
                                           method_getImplementation(swizzledMethod),
                                           method_getTypeEncoding(swizzledMethod))

        if (didAddMethod) {
            class_replaceMethod(classToSwizzle,
                                swizzledSelector,
                                method_getImplementation(originalMethod),
                                method_getTypeEncoding(originalMethod));
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    }

}
