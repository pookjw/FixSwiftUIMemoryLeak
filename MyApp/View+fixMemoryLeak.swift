//
//  View+fixMemoryLeak.swift
//  MyApp
//
//  Created by Jinwoo Kim on 1/4/24.
//

import SwiftUI

let storageKey: UnsafeMutableRawPointer = .allocate(byteCount: 1, alignment: 1)
fileprivate let didFixKey_1: UnsafeMutableRawPointer = .allocate(byteCount: 1, alignment: 1)
fileprivate let didFixKey_2: UnsafeMutableRawPointer = .allocate(byteCount: 1, alignment: 1)
fileprivate var didSwizzle: Bool = false

extension View {
  func fixMemoryLeak() -> some View {
    if #available(iOS 17.2, *) {
      return self
    }

    swizzle()
    return background {
      FixLeakView()
    }
  }
}

fileprivate struct FixLeakView: UIViewControllerRepresentable {
  func makeUIViewController(context: Context) -> ViewController {
    .init()
  }

  func updateUIViewController(_ uiViewController: ViewController, context: Context) {

  }

  @MainActor final class ViewController: UIViewController {

    override func viewDidLoad() {
      super.viewDidLoad()
      view.isUserInteractionEnabled = false
      view.backgroundColor = .clear
    }

    override func didMove(toParent parent: UIViewController?) {
      super.didMove(toParent: parent)

      if #available(iOS 17.2, *) {
        return
      }

      guard
        let type: UIViewController.Type = NSClassFromString("_TtGC7SwiftUI29PresentationHostingControllerVS_7AnyView_") as? UIViewController.Type,
        let hostingController: UIViewController = parentViewController(for: type) else {
        return
      }

      for child in Mirror(reflecting: hostingController).children {
        if child.label == "delegate" {
          for child in Mirror(reflecting: child.value).children {
            if child.label == "some" {
              for child in Mirror(reflecting: child.value).children {
                if child.label == "presentationState" {
                  for child in Mirror(reflecting: child.value).children {
                    if child.label == "base" {
                      for child in Mirror(reflecting: child.value).children {
                        if child.label == "requestedPresentation" {
                          for child in Mirror(reflecting: child.value).children {
                            if child.label == ".0" {
                              for child in Mirror(reflecting: child.value).children {
                                if child.label == "content" {
                                  for child in Mirror(reflecting: child.value).children {
                                    if child.label == "storage" {
                                      let didFix: Bool = objc_getAssociatedObject(child.value, didFixKey_1) as? Bool ?? false

                                      guard !didFix else {
                                        break
                                      }

                                      let unmanaged = Unmanaged.passUnretained(child.value as AnyObject)
                                      unmanaged.release()
                                      unmanaged.release()
                                      unmanaged.release()

                                      objc_setAssociatedObject(child.value, didFixKey_1, true, .OBJC_ASSOCIATION_COPY_NONATOMIC)
                                      objc_setAssociatedObject(hostingController, storageKey, child.value, .OBJC_ASSOCIATION_ASSIGN)
                                      break
                                    }
                                  }
                                  break
                                }
                              }
                              break
                            }
                          }
                          break
                        }
                      }
                      break
                    }
                  }
                  break
                }
              }
              break
            }
          }
          break
        }
      }
    }
  }
}

fileprivate func swizzle() {
  guard !didSwizzle else { return }
  defer { didSwizzle = true }

  let method: Method = class_getInstanceMethod(UIViewController.self,
                                               NSSelectorFromString("dismissViewControllerAnimated:completion:"))!
  let original_imp: IMP = method_getImplementation(method)
  let original_func: @convention(c) (AnyObject, Selector, Bool, AnyObject) -> Void = unsafeBitCast(original_imp, to: (@convention(c) (AnyObject, Selector, Bool, AnyObject) -> Void).self)

  let new_func: @convention(block) (AnyObject, Bool, AnyObject) -> Void = { x0, x1, x2 in
    if
      let hostingController: UIViewController = (x0 as? UIViewController)?.presentedViewController,
      let storage: AnyObject = objc_getAssociatedObject(hostingController, storageKey) as? AnyObject,
      objc_getAssociatedObject(storage, didFixKey_2) as? Bool ?? true
    {
      let umanaged: Unmanaged<AnyObject> = .passUnretained(storage)
      _ = umanaged.retain()

      var hasOverFullScreen: Bool = false
      var vc: UIViewController? = hostingController
      while let _vc = vc {
        hasOverFullScreen = _vc.modalPresentationStyle == .overFullScreen

        if hasOverFullScreen {
          break
        }

        vc = _vc.presentingViewController
      }

      if hasOverFullScreen {
        _ = umanaged.retain()
      }

      objc_setAssociatedObject(storage, didFixKey_2, true, .OBJC_ASSOCIATION_COPY_NONATOMIC)
    }

    original_func(x0, NSSelectorFromString("dismissViewControllerAnimated:completion:"), x1, x2)
  }

  let new_imp: IMP = imp_implementationWithBlock(new_func)
  method_setImplementation(method, new_imp)
}


extension UIViewController {
  fileprivate func parentViewController(for type: UIViewController.Type) -> UIViewController? {
    var responder: UIViewController? = parent

    while let _responder: UIViewController = responder {
      if _responder.isKind(of: type) {
        return _responder
      }

      responder = _responder.parent
    }

    return responder
  }
}