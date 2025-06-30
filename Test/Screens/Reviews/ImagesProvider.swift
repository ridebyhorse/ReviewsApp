//
//  ImagesProvider.swift
//  Test
//
//  Created by Maria Nesterova on 30.06.2025.
//

import UIKit

/// Класс для загрузки изображений.
final class ImagesProvider {
    
    private let images: NSCache<NSString, UIImage>

    init(images: NSCache<NSString, UIImage> = NSCache<NSString, UIImage>()) {
        self.images = images
    }

}

// MARK: - Internal

extension ImagesProvider {

    typealias GetImageResult = Result<UIImage, GetImageError>

    enum GetImageError: Error {

        case badURL
        case invalidResponse
        case conversionFailed
        case badData(Error)

    }

    func getImageAndCache(urlString: String?, completion: @escaping (GetImageResult) -> Void) {
        guard let urlString, let url = URL(string: urlString) else {
            return completion(.failure(.badURL))
        }
        
        if let cachedImage = images.object(forKey: urlString as NSString) {
            return completion(.success(cachedImage))
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let error {
                return completion(.failure(.badData(error)))
            }
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return completion(.failure(.invalidResponse))
            }
            
            guard let data, let image = UIImage(data: data) else {
                return completion(.failure(.conversionFailed))
            }
            
            self?.images.setObject(image, forKey: urlString as NSString)
            
            DispatchQueue.main.async {
                completion(.success(image))
            }
        }
        .resume()
    }

}
