import Foundation

struct SafeDecodableArray<Element: Decodable>: Decodable {
    let elements: [Element]

    private struct DummyDecodable: Decodable {}

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var elements = [Element]()
        while !container.isAtEnd {
            do {
                let element = try container.decode(Element.self)
                elements.append(element)
            } catch {
                _ = try? container.decode(DummyDecodable.self)
            }
        }
        self.elements = elements
    }
}
