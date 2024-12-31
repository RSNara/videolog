//
//  ContentView.swift
//  videolog
//
//  Created by Ramanpreet Nara on 12/27/24.
//

import SwiftUI
import Photos
import CoreLocation
import AVFoundation
import Foundation

class PhotosManager: ObservableObject {
  @Published var status: PHAuthorizationStatus = .notDetermined
  @Published var videoMap: [Studio: [PHAsset]] = [:]
  
  func requestAccess() {
    PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
      DispatchQueue.main.async {
        self.status = status
      }
    }
  }
  
  func prefetchVideos(for studio: Studio) {
    guard status == .authorized else { return }
    guard videoMap[studio] == nil else { return }
    
    let studioLocation = CLLocation(latitude: studio.latitude, longitude: studio.longitude)
    
    let fetchOptions = PHFetchOptions()
    let fetchResults = PHAsset.fetchAssets(with: .video, options: fetchOptions)
    
    var nearbyAssets: [PHAsset] = []
    var components = DateComponents()
    components.year = 2024
    components.month = 12
    components.day = 1
    
    let dec22nd2024 = Calendar.current.date(from: components)!
    
    fetchResults.enumerateObjects { asset, _, _ in
      if let location = asset.location {
        let assetLocation = CLLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        let distance = studioLocation.distance(from: assetLocation)
        
        let assetDate = asset.creationDate
        if assetDate != nil && dec22nd2024 < assetDate! && distance <= studio.radius {
          nearbyAssets.append(asset)
        }
      }
    }
    
    videoMap[studio] = nearbyAssets;
  }
}

struct Studio: Identifiable, Hashable {
  let id = UUID()
  let name: String
  let latitude: Double
  let longitude: Double
  let radius: Double
  
  func hash(into hasher: inout Hasher) {
    hasher.combine(self.id)
  }
  
  static func == (lhs: Studio, rhs: Studio) -> Bool {
    return lhs.id == rhs.id
  }
}

class GlobalStore: ObservableObject {
  @Published var studios: [Studio] = [Studio(
    name: "Inspiration Studios",
    latitude: 37.484778,
    longitude: -122.228150,
    radius: 1000
  )]
}

struct ContentView: View {
  @StateObject private var store = GlobalStore()
  @StateObject private var photosManager = PhotosManager()
  
  var body: some View {
    NavigationView {
      VStack(spacing: 10) {
        if photosManager.status == .authorized {
          ForEach(store.studios.indices, id: \.self) { index in
            NavigationLink(destination: VideoLogsView(studio: store.studios[index]).environmentObject(photosManager)) {
              Text(store.studios[index].name)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
          }
        } else if photosManager.status == .denied {
          Text("Access to Photos denied. Please enable it in Settings.")
        } else {
          Text("Requesting access to Photos...")
        }
      }
    }.onAppear {
      photosManager.requestAccess()
    }
  }
}

struct VideoLogsView: View {
  @EnvironmentObject private var photosManager: PhotosManager
  let studio: Studio
  var body: some View {
    VStack {
      if let videos = photosManager.videoMap[studio] {
        if (!videos.isEmpty) {
          Video(video:videos[0])
        }
      } else {
        Text("Could not fetch videos")
      }
    }
    .navigationTitle(studio.name)
    .onAppear {
      photosManager.prefetchVideos(for: studio)
    }
  }
}

struct Video: View {
  @State private var caption = ""
  let video: PHAsset
  
  var body: some View {
    Text("Caption: \(caption)")
      .onAppear {
        printMetadata(for: video)
      }
  }
  
  func printMetadata(for asset: PHAsset) {
    // Ensure the asset is a video
    guard asset.mediaType == .video else {
        print("The PHAsset is not a video.")
        return
    }
    
    // Request the video URL from PHAsset
    let options = PHVideoRequestOptions()
    options.isNetworkAccessAllowed = true // Allow fetching from iCloud if necessary
    
    PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { (avAsset, audioMix, info) in
      guard let avAsset = avAsset else {
        print("Failed to retrieve AVAsset.")
        return
      }
      
      Task {
        do {
          for format in try await avAsset.load(.availableMetadataFormats) {
            let metadata = try await avAsset.loadMetadata(for: format)
            for item in metadata {
              if let key = item.commonKey?.rawValue, let value = item.value {
                print("\(key): \(value)")
              }
            }
          }
        } catch {
          print("Error while printin metadata")
        }
      }
      
//      // Use AVAsset to read metadata
//      let metadataItems = avAsset.commonMetadata
//      print("AVAsset Common Metadata:")
//      for item in metadataItems {
//        if let key = item.commonKey?.rawValue, let value = item.value {
//          print("\(key): \(value)")
//        }
//      }
//      
//      // If the video is a URL asset, extract file-specific metadata
//      if let urlAsset = avAsset as? AVURLAsset {
//        print("Video URL: \(urlAsset.url)")
//        
//        // Extract additional metadata from the file using AVAssetTrack or other APIs
//        let videoTracks = urlAsset.tracks(withMediaType: .video)
//        if let videoTrack = videoTracks.first {
//          print("Video Dimensions: \(videoTrack.naturalSize)")
//          print("Frame Rate: \(videoTrack.nominalFrameRate) FPS")
//        }
//      }
    }
  }
}
