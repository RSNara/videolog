//
//  ContentView.swift
//  videolog
//
//  Created by Ramanpreet Nara on 12/27/24.
//

import SwiftUI
import Photos
import PhotosUI
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
    
    let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date())
    var nearbyAssets: [PHAsset] = []
    
    fetchResults.enumerateObjects { asset, _, _ in
      if let location = asset.location {
        let assetLocation = CLLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        let distance = studioLocation.distance(from: assetLocation)
        
        if let creationDate = asset.creationDate {
          if creationDate >= (sixMonthsAgo ?? Date.distantPast) && distance <= studio.radius {
            nearbyAssets.append(asset)
          }
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

struct AssetThumbnailView: View {
  let asset: PHAsset
  @State private var thumbnail: UIImage? = nil

  var body: some View {
    Group {
      if let thumbnail = thumbnail {
        Image(uiImage: thumbnail)
          .frame(width: 100, height: 100)
      } else {
        Rectangle()
          .fill(Color.gray)
          .frame(width:100, height: 100)
          .overlay(Text("Loading...").foregroundColor(.white))
      }
    }
    .onAppear {
        fetchThumbnail(for: asset)
    }
  }

  private func fetchThumbnail(for asset: PHAsset) {
    let imageManager = PHImageManager.default()
    let targetSize = CGSize(width: 100, height: 100) // Thumbnail size
    let options = PHImageRequestOptions()
    options.deliveryMode = .highQualityFormat
    options.resizeMode = .fast
    options.isSynchronous = false
    options.isNetworkAccessAllowed = true

    imageManager.requestImage(
      for: asset,
      targetSize: targetSize,
      contentMode: .aspectFill,
      options: options)
    { image, info in
      if let image = image {
        DispatchQueue.main.async {
            self.thumbnail = image
        }
      }
    }
  }
}

class GlobalStore: ObservableObject {
  @Published var studios: [Studio] = [
    Studio(
      name: "Inspiration Studios",
      latitude: 37.47567,
      longitude: -122.21316,
      radius: 100
    )
  ]
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
  let columns = [
    GridItem(.fixed(100)),
    GridItem(.fixed(100)),
    GridItem(.fixed(100)),
    GridItem(.fixed(100))
  ]
  
  var body: some View {
    NavigationView {
      ScrollView {
        LazyVGrid(columns: columns) { // Create the grid
          if let videos = photosManager.videoMap[studio] {
            ForEach(videos, id: \.self) { video in
              AssetThumbnailView(asset: video)
                .padding()
            }
          }
        }
      }
      .safeAreaInset(edge: .top) {
        Color.clear.frame(height: 11) // Add a spacer to clear navigation bar
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
