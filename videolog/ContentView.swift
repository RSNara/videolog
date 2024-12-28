//
//  ContentView.swift
//  videolog
//
//  Created by Ramanpreet Nara on 12/27/24.
//

import SwiftUI
import Photos

class PhotosPermissionManager: ObservableObject {
  @Published var status: PHAuthorizationStatus = .notDetermined
  
  func requestAccess() {
    PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
      DispatchQueue.main.async {
        self.status = status
      }
    }
  }
}

struct Studio: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
}

class GlobalStore: ObservableObject {
  @Published var studios: [Studio] = [Studio(
    name: "Inspiration Studios",
    coordinate: CLLocationCoordinate2D(
      latitude: 37.484778,
      longitude: -122.228150
    )
  )]
}

struct ContentView: View {
  @StateObject private var store = GlobalStore()
  @StateObject private var photosPermissionManager = PhotosPermissionManager()
  
  var body: some View {
    NavigationView {
      VStack(spacing: 10) {
        if photosPermissionManager.status == .authorized {
          ForEach(store.studios.indices, id: \.self) { index in
            NavigationLink(destination: VideoLogsView(studio: store.studios[index])) {
              Text(store.studios[index].name)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
          }
        } else if photosPermissionManager.status == .denied {
          Text("Access to Photos denied. Please enable it in Settings.")
        } else {
          Text("Requesting access to Photos...")
        }
      }
    }.onAppear {
      photosPermissionManager.requestAccess()
    }
  }
}

struct VideoLogsView: View {
  let studio: Studio
  var body: some View {
    VStack {
        
    }
    .navigationTitle(studio.name)
  }
}
