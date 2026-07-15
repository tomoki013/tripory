import Foundation
import MapKit

/// Natural Earth 110m国境データ(ISO A2コード付き)を読み込み、国ごとのMKPolygon/MKMultiPolygonに変換する。
enum CountryBorders {
    private struct GeoJSON: Decodable {
        let features: [Feature]
    }

    private struct Feature: Decodable {
        let properties: Properties
        let geometry: Geometry
    }

    private struct Properties: Decodable {
        let code: String
    }

    private struct Geometry: Decodable {
        let type: String
        let coordinates: Coordinates
    }

    /// Polygon: [ [ [lon,lat], ... ] ]  MultiPolygon: [ [ [ [lon,lat], ... ] ] ]
    private enum Coordinates: Decodable {
        case polygon([[[Double]]])
        case multiPolygon([[[[Double]]]])

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let multi = try? container.decode([[[[Double]]]].self) {
                self = .multiPolygon(multi)
            } else {
                self = .polygon(try container.decode([[[Double]]].self))
            }
        }
    }

    static let polygonsByCode: [String: [MKPolygon]] = {
        guard let url = Bundle.main.url(forResource: "CountryBorders", withExtension: "geojson"),
              let data = try? Data(contentsOf: url),
              let geoJSON = try? JSONDecoder().decode(GeoJSON.self, from: data)
        else { return [:] }

        var result: [String: [MKPolygon]] = [:]
        for feature in geoJSON.features {
            // multiPolygon: 各要素が [outerRing, hole1, hole2, ...] の配列
            let polygons: [MKPolygon]
            switch feature.geometry.coordinates {
            case .polygon(let coords):
                polygons = [Self.makePolygon(rings: coords)]
            case .multiPolygon(let coords):
                polygons = coords.map { Self.makePolygon(rings: $0) }
            }
            result[feature.properties.code, default: []].append(contentsOf: polygons)
        }
        return result
    }()

    private static func makePolygon(rings: [[[Double]]]) -> MKPolygon {
        guard let outer = rings.first else { return MKPolygon(coordinates: [], count: 0) }
        let outerCoords = outer.map { CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0]) }
        let interiorPolygons: [MKPolygon] = rings.dropFirst().map { hole in
            let coords = hole.map { CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0]) }
            return MKPolygon(coordinates: coords, count: coords.count)
        }
        if interiorPolygons.isEmpty {
            return MKPolygon(coordinates: outerCoords, count: outerCoords.count)
        }
        return MKPolygon(coordinates: outerCoords, count: outerCoords.count, interiorPolygons: interiorPolygons)
    }
}
