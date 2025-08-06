//
//  GroupWorkout+Sharing.swift
//  FameFit
//
//  Extensions for sharing group workouts via deep links
//

import Foundation

extension GroupWorkout {
    // MARK: - Deep Link Generation
    
    /// Generates a deep link URL for this workout
    var deepLinkURL: URL? {
        var components = URLComponents()
        components.scheme = "famefit"
        components.host = "groupworkout"
        components.path = "/\(id)"
        
        return components.url
    }
    
    /// Generates a universal link for sharing (if configured)
    var universalLinkURL: URL? {
        // This would be configured with your domain
        // Example: https://famefit.app/groupworkout/abc123
        var components = URLComponents()
        components.scheme = "https"
        components.host = "famefit.app" // Replace with your actual domain
        components.path = "/groupworkout/\(id)"
        
        return components.url
    }
    
    /// Generates a shareable text message for the workout
    var shareText: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        var text = "Join me for \(name)!\n"
        text += "🏃 \(workoutType.displayName)\n"
        text += "📅 \(dateFormatter.string(from: scheduledStart))\n"
        
        if let location = location {
            text += "📍 \(location)\n"
        }
        
        if !isPublic, let code = joinCode {
            text += "🔐 Join code: \(code)\n"
        }
        
        if let deepLink = deepLinkURL {
            text += "\nTap to join: \(deepLink.absoluteString)"
        }
        
        return text
    }
    
    /// Generates activity items for sharing
    var activityItems: [Any] {
        // Only include the share text which already contains the link
        // Adding the URL separately causes it to appear twice
        return [shareText]
    }
}