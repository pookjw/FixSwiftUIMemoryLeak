//
//  MyAppApp.swift
//  MyApp
//
//  Created by Jinwoo Kim on 1/4/24.
//

import SwiftUI

@main
struct MyAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
  @State private var isPresenting: Bool = false

  var body: some View {
      Button("Present") {
        isPresenting = true
      }
    .fullScreenCover(isPresented: $isPresenting) {
      SheetView()
        .fixMemoryLeak()
    }
  }
}

struct SheetView: View {
  @Environment(\.dismiss) var dismiss
  @State private var isPresenting: Bool = false

  var body: some View {
    VStack {
      Button("Present") {
        isPresenting = true
      }

      Button("Dismiss") {
        dismiss()
      }
    }
    .fullScreenCover(isPresented: $isPresenting) {
      SheetView_2()
        .fixMemoryLeak()
    }
  }
}

struct SheetView_2: View {
  @Environment(\.dismiss) var dismiss
  private let viewModel: ViewModel = .init()

  var body: some View {
    VStack {


      Button("Dismiss") {
        dismiss()
      }
    }
  }
}

class ViewModel {
  init() {
    print("init")
  }

  deinit {
    print("deinit")
  }
}
