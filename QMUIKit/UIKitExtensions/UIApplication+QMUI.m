/**
 * Tencent is pleased to support the open source community by making QMUI_iOS available.
 * Copyright (C) 2016-2021 THL A29 Limited, a Tencent company. All rights reserved.
 * Licensed under the MIT License (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at
 * http://opensource.org/licenses/MIT
 * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
 */
//
//  UIApplication+QMUI.m
//  QMUIKit
//
//  Created by MoLice on 2021/8/30.
//

#import "UIApplication+QMUI.h"
#import "QMUICore.h"

@implementation UIApplication (QMUI)

QMUISynthesizeBOOLProperty(qmui_didFinishLaunching, setQmui_didFinishLaunching)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        OverrideImplementation(object_getClass(UIApplication.class), @selector(sharedApplication), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
            return ^UIApplication *(UIApplication *selfObject) {
                // call super
                UIApplication * (*originSelectorIMP)(id, SEL);
                originSelectorIMP = (UIApplication * (*)(id, SEL))originalIMPProvider();
                UIApplication * result = originSelectorIMP(selfObject, originCMD);
                
                if (![result qmui_getBoundBOOLForKey:@"QMUIAddedObserver"]) {
                    [NSNotificationCenter.defaultCenter addObserver:result selector:@selector(qmui_handleDidFinishLaunchingNotification:) name:UIApplicationDidFinishLaunchingNotification object:nil];
                    [result qmui_bindBOOL:YES forKey:@"QMUIAddedObserver"];
                }
                
                return result;
            };
        });
    });
}

- (void)qmui_handleDidFinishLaunchingNotification:(NSNotification *)notification {
    self.qmui_didFinishLaunching = YES;
    [NSNotificationCenter.defaultCenter removeObserver:self name:UIApplicationDidFinishLaunchingNotification object:nil];
}

/// 获取应用的所有窗口
/// 优先从 iOS 13+ 的 Scene API 中获取窗口，如果不存在则回退到旧的 windows 属性
/// @return 窗口数组，如果不存在则返回空数组
- (NSArray<__kindof UIWindow *> *)qmui_windows {
    __block NSArray *windows = nil;
    // 遍历所有已连接的场景，查找 UIWindowScene 类型且 role 为 Application 的场景
    [self.connectedScenes enumerateObjectsUsingBlock:^(UIScene *scene, BOOL *stop) {
        if ([scene isKindOfClass:UIWindowScene.class] && [scene.session.role isEqualToString:UIWindowSceneSessionRoleApplication]) {
            windows = [(UIWindowScene *)scene windows];
            *stop = YES; // 找到第一个符合条件的场景后立即停止
        }
    }];
    // 如果通过 Scene API 没有找到窗口，回退到 iOS 13 之前的 windows 属性
    if (!windows || windows.count == 0) {
        windows = self.windows;
    }
    return windows ? : @[];
}

/// 获取当前的关键窗口（key window）
/// 查找优先级：1. Scene API 中的 key window  2. 已废弃的 keyWindow 属性  3. delegate 的 window
/// @return 关键窗口，如果不存在则返回 nil
- (nullable __kindof UIWindow *)qmui_keyWindow {
    __block UIWindow *keyWindow = nil;
    // 遍历所有已连接的场景，查找 UIWindowScene 类型且 role 为 Application 的场景
    [self.connectedScenes enumerateObjectsUsingBlock:^(UIScene *scene, BOOL *stop) {
        if ([scene isKindOfClass:UIWindowScene.class] && [scene.session.role isEqualToString:UIWindowSceneSessionRoleApplication]) {
            // 遍历该场景下的所有窗口，查找 key window 且未隐藏的窗口
            [[(UIWindowScene *)scene windows] enumerateObjectsUsingBlock:^(UIWindow *window, NSUInteger idx, BOOL *stop) {
                if (window.isKeyWindow && !window.isHidden) {
                    keyWindow = window;
                    *stop = YES; // 找到 key window 后立即停止内层枚举
                }
            }];
            // 如果已找到 key window，停止外层枚举；否则继续检查下一个 scene
            if (keyWindow) {
                *stop = YES;
            }
        }
    }];
    // 如果通过 Scene API 没有找到 key window，回退到已废弃的 keyWindow 属性（iOS 13 之前）
    if (!keyWindow) {
        BeginIgnoreDeprecatedWarning
        keyWindow = self.keyWindow;
        EndIgnoreDeprecatedWarning
    }
    // 如果还是没有找到，尝试从 delegate 获取 window
    if (!keyWindow) {
        keyWindow = self.qmui_delegateWindow;
    }
    return keyWindow;
}

/// 获取 delegate 的 window
/// 查找优先级：1. Scene delegate 的 window  2. App delegate 的 window
/// @return delegate 的 window，如果不存在则返回 nil
- (nullable __kindof UIWindow *)qmui_delegateWindow {
    __block UIWindow *delegateWindow = nil;
    // 遍历所有已连接的场景，查找 UIWindowScene 类型且 role 为 Application 的场景
    [self.connectedScenes enumerateObjectsUsingBlock:^(UIScene *scene, BOOL *stop) {
        if ([scene isKindOfClass:UIWindowScene.class] && [scene.session.role isEqualToString:UIWindowSceneSessionRoleApplication]) {
            // 检查 scene delegate 是否实现了 window 方法
            if ([scene.delegate respondsToSelector:@selector(window)]) {
                delegateWindow = [scene.delegate performSelector:@selector(window)];
                *stop = YES; // 找到第一个符合条件的场景后立即停止
            }
        }
    }];
    // 如果通过 Scene delegate 没有找到 window，尝试从 App delegate 获取
    if (!delegateWindow && [self.delegate respondsToSelector:@selector(window)]) {
        delegateWindow = [self.delegate performSelector:@selector(window)];
    }
    return delegateWindow;
}

@end
