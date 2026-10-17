import SwiftUI

public extension ApolloChartTheme {
    /// Owner-selected Ascending A lead palette. Parent supplies cool-white background #F4F7FF.
    /// Apply with the app's shared light-theme adoption, not onto the legacy ink surface.
    static var blueOnLight: ApolloChartTheme {
        ApolloChartTheme(
            accent: Color(red: 50.0 / 255, green: 104.0 / 255, blue: 223.0 / 255),
            text: Color(red: 11.0 / 255, green: 20.0 / 255, blue: 40.0 / 255),
            muted: Color(red: 82.0 / 255, green: 96.0 / 255, blue: 122.0 / 255),
            caution: Color(red: 145.0 / 255, green: 73.0 / 255, blue: 0),
            surface: Color.white
        )
    }

    /// Owner-selected secondary midnight reverse. Parent supplies midnight background #0B1428.
    static var midnightReverse: ApolloChartTheme {
        ApolloChartTheme(
            accent: Color(red: 100.0 / 255, green: 149.0 / 255, blue: 1),
            text: Color(red: 244.0 / 255, green: 247.0 / 255, blue: 1),
            muted: Color(red: 166.0 / 255, green: 180.0 / 255, blue: 205.0 / 255),
            caution: Color(red: 240.0 / 255, green: 188.0 / 255, blue: 112.0 / 255),
            surface: Color(red: 21.0 / 255, green: 35.0 / 255, blue: 61.0 / 255)
        )
    }
}
