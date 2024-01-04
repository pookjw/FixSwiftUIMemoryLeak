//
//  View+fixMemoryLeak.swift
//  MyApp
//
//  Created by Jinwoo Kim on 1/4/24.
//

import UIKit
import SwiftUI

fileprivate let storageKey: UnsafeMutableRawPointer = .allocate(byteCount: 1, alignment: 1)
fileprivate let willDealloc: UnsafeMutableRawPointer = .allocate(byteCount: 1, alignment: 1)
fileprivate var didSwizzle: Bool = false

extension View {
  func fixMemoryLeak() -> some View {
    if #available(iOS 17.2, *) {
      return self
    } else if #available(iOS 17.0, *) {
      swizzle()
      return background {
        FixLeakView()
      }
    } else {
      return self
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

      guard
        let type: UIViewController.Type = NSClassFromString("_TtGC7SwiftUI29PresentationHostingControllerVS_7AnyView_") as? UIViewController.Type,
        let hostingController: UIViewController = parentViewController(for: type) else {
        return
      }

      if 
        let delegate = Mirror(reflecting: hostingController).children.first(where: { $0.label == "delegate" })?.value,
        let some = Mirror(reflecting: delegate).children.first(where: { $0.label == "some" })?.value,
        let presentationState = Mirror(reflecting: some).children.first(where: { $0.label == "presentationState" })?.value,
        let base = Mirror(reflecting: presentationState).children.first(where: { $0.label == "base" })?.value,
        let requestedPresentation = Mirror(reflecting: base).children.first(where: { $0.label == "requestedPresentation" })?.value,
        let value = Mirror(reflecting: requestedPresentation).children.first(where: { $0.label == ".0" })?.value,
        let content = Mirror(reflecting: value).children.first(where: { $0.label == "content" })?.value,
        let storage = Mirror(reflecting: content).children.first(where: { $0.label == "storage" })?.value
      {
        objc_setAssociatedObject(hostingController, storageKey, storage, .OBJC_ASSOCIATION_ASSIGN)
      }
    }
  }
}

fileprivate func swizzle() {
  guard !didSwizzle else { return }
  defer { didSwizzle = true }

  let method: Method = class_getInstanceMethod(
    NSClassFromString("_TtGC7SwiftUI29PresentationHostingControllerVS_7AnyView_")!,
    #selector(UIViewController.viewDidDisappear(_:))
  )!
  let original_imp: IMP = method_getImplementation(method)
  let original_func = unsafeBitCast(original_imp, to: (@convention(c) (UIViewController, Selector, Bool) -> Void).self)

  let new_func: @convention(block) (UIViewController, Bool) -> Void = { x0, x1 in
    if
      x0.isMovingFromParent || x0.isBeingDismissed,
      let storage: AnyObject = objc_getAssociatedObject(x0, storageKey) as? AnyObject,
      !(storage is NSNull),
      objc_getAssociatedObject(storage, willDealloc) as? Bool ?? true
    {
      Task { @MainActor [unowned storage] in
//        guard try? await Task.sleep(for: .seconds(0.3)) else {
//          return
//        }

        let retainCount: UInt = _getRetainCount(storage)
        let umanaged: Unmanaged<AnyObject> = .passUnretained(storage)

        for _ in 0..<retainCount - 1 {
          umanaged.release()
        }
      }

      objc_setAssociatedObject(storage, willDealloc, true, .OBJC_ASSOCIATION_COPY_NONATOMIC)
    }

    original_func(x0, #selector(UIViewController.viewDidDisappear(_:)), x1)
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
