//
//  ComplicationController.swift
//  FameFit Watch App
//
//  Created by paige on 2021/12/11.
//

#if os(watchOS)
    import ClockKit

    class ComplicationController: NSObject, CLKComplicationDataSource {
        // MARK: - Data Provider
        
        private let dataProvider: ComplicationDataProviding
        
        init(dataProvider: ComplicationDataProviding = ProductionComplicationDataProvider(workoutManager: nil)) {
            self.dataProvider = dataProvider
            super.init()
        }
        
        // MARK: - Complication Configuration

        func getComplicationDescriptors(handler: @escaping ([CLKComplicationDescriptor]) -> Void) {
            let descriptors = [
                CLKComplicationDescriptor(
                    identifier: "complication",
                    displayName: "FameFit",
                    supportedFamilies: CLKComplicationFamily.allCases
                )
                // Multiple complication support can be added here with more descriptors
            ]

            // Call the handler with the currently supported complication descriptors
            handler(descriptors)
        }

        func handleSharedComplicationDescriptors(_: [CLKComplicationDescriptor]) {
            // Do any necessary work to support these newly shared complication descriptors
        }

        // MARK: - Timeline Configuration

        func getTimelineEndDate(for _: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
            // Call the handler with the last entry date you can currently provide
            // or nil if you can't support future timelines
            handler(nil)
        }

        func getPrivacyBehavior(
            for _: CLKComplication,
            withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void
        ) {
            // Call the handler with your desired behavior when the device is locked
            handler(.showOnLockScreen)
        }

        // MARK: - Timeline Population

        func getCurrentTimelineEntry(
            for complication: CLKComplication,
            withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void
        ) {
            // Create template based on complication family
            let template = createTemplate(for: complication.family)
            let timelineEntry = CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template)
            handler(timelineEntry)
        }

        func getTimelineEntries(
            for _: CLKComplication,
            after _: Date,
            limit _: Int,
            withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void
        ) {
            // Call the handler with the timeline entries after the given date
            handler(nil)
        }

        // MARK: - Sample Templates

        func getLocalizableSampleTemplate(
            for complication: CLKComplication,
            withHandler handler: @escaping (CLKComplicationTemplate?) -> Void
        ) {
            // This method will be called once per supported complication, and the results will be cached
            let template = createTemplate(for: complication.family)
            handler(template)
        }
        
        // MARK: - Template Creation
        
        private func createTemplate(for family: CLKComplicationFamily) -> CLKComplicationTemplate {
            switch family {
            case .modularSmall:
                return createModularSmallTemplate()
            case .modularLarge:
                return createModularLargeTemplate()
            case .circularSmall:
                return createCircularSmallTemplate()
            case .graphicCorner:
                return createGraphicCornerTemplate()
            case .graphicCircular:
                return createGraphicCircularTemplate()
            case .graphicRectangular:
                return createGraphicRectangularTemplate()
            default:
                return createModularSmallTemplate()
            }
        }
        
        private func createModularSmallTemplate() -> CLKComplicationTemplate {
            if dataProvider.isWorkoutActive {
                let minutes = Int(dataProvider.workoutElapsedTime / 60)
                let textProvider = CLKSimpleTextProvider(text: "\(minutes)m")
                return CLKComplicationTemplateModularSmallSimpleText(textProvider: textProvider)
            } else {
                let textProvider = CLKSimpleTextProvider(text: "\(dataProvider.currentXP)")
                return CLKComplicationTemplateModularSmallSimpleText(textProvider: textProvider)
            }
        }
        
        private func createModularLargeTemplate() -> CLKComplicationTemplate {
            let headerTextProvider = CLKSimpleTextProvider(text: "FameFit")
            
            if dataProvider.isWorkoutActive {
                let minutes = Int(dataProvider.workoutElapsedTime / 60)
                let calories = Int(dataProvider.workoutActiveEnergy)
                let body1TextProvider = CLKSimpleTextProvider(text: "Active: \(minutes)m")
                let body2TextProvider = CLKSimpleTextProvider(text: "\(calories) cal")
                return CLKComplicationTemplateModularLargeStandardBody(
                    headerTextProvider: headerTextProvider,
                    body1TextProvider: body1TextProvider,
                    body2TextProvider: body2TextProvider
                )
            } else {
                let body1TextProvider = CLKSimpleTextProvider(text: "XP: \(dataProvider.currentXP)")
                let body2TextProvider = CLKSimpleTextProvider(text: "Streak: \(dataProvider.currentStreak)")
                return CLKComplicationTemplateModularLargeStandardBody(
                    headerTextProvider: headerTextProvider,
                    body1TextProvider: body1TextProvider,
                    body2TextProvider: body2TextProvider
                )
            }
        }
        
        private func createCircularSmallTemplate() -> CLKComplicationTemplate {
            let textProvider = CLKSimpleTextProvider(text: "\(dataProvider.currentLevel)")
            return CLKComplicationTemplateCircularSmallSimpleText(textProvider: textProvider)
        }
        
        private func createGraphicCornerTemplate() -> CLKComplicationTemplate {
            let textProvider = CLKSimpleTextProvider(text: "\(dataProvider.currentXP)")
            
            // Use system image for workout state
            let imageName = dataProvider.isWorkoutActive ? "figure.run" : "star.fill"
            if let image = UIImage(systemName: imageName) {
                let imageProvider = CLKFullColorImageProvider(fullColorImage: image)
                return CLKComplicationTemplateGraphicCornerTextImage(
                    textProvider: textProvider,
                    imageProvider: imageProvider
                )
            } else {
                // Fallback to text-only template
                return CLKComplicationTemplateGraphicCornerStackText(
                    innerTextProvider: textProvider,
                    outerTextProvider: CLKSimpleTextProvider(text: "XP")
                )
            }
        }
        
        private func createGraphicCircularTemplate() -> CLKComplicationTemplate {
            // Show progress towards next level
            let currentLevelXP = dataProvider.currentLevel * 1000
            let nextLevelXP = (dataProvider.currentLevel + 1) * 1000
            let progress = Float(dataProvider.currentXP - currentLevelXP) / Float(nextLevelXP - currentLevelXP)
            
            let centerTextProvider = CLKSimpleTextProvider(text: "L\(dataProvider.currentLevel)")
            let bottomTextProvider = CLKSimpleTextProvider(text: "\(dataProvider.currentStreak)")
            let gaugeProvider = CLKSimpleGaugeProvider(style: .fill, gaugeColor: .green, fillFraction: progress)
            
            return CLKComplicationTemplateGraphicCircularOpenGaugeSimpleText(
                gaugeProvider: gaugeProvider,
                bottomTextProvider: bottomTextProvider,
                centerTextProvider: centerTextProvider
            )
        }
        
        private func createGraphicRectangularTemplate() -> CLKComplicationTemplate {
            let headerTextProvider = CLKSimpleTextProvider(text: "FameFit")
            
            if dataProvider.isWorkoutActive {
                let minutes = Int(dataProvider.workoutElapsedTime / 60)
                let calories = Int(dataProvider.workoutActiveEnergy)
                let body1TextProvider = CLKSimpleTextProvider(text: "Active Workout")
                let body2TextProvider = CLKSimpleTextProvider(text: "\(minutes)m • \(calories) cal")
                return CLKComplicationTemplateGraphicRectangularStandardBody(
                    headerTextProvider: headerTextProvider,
                    body1TextProvider: body1TextProvider,
                    body2TextProvider: body2TextProvider
                )
            } else {
                let body1TextProvider = CLKSimpleTextProvider(text: "Level \(dataProvider.currentLevel) • \(dataProvider.currentXP) XP")
                let body2TextProvider = CLKSimpleTextProvider(text: "\(dataProvider.currentStreak) day streak")
                return CLKComplicationTemplateGraphicRectangularStandardBody(
                    headerTextProvider: headerTextProvider,
                    body1TextProvider: body1TextProvider,
                    body2TextProvider: body2TextProvider
                )
            }
        }
    }
#endif
