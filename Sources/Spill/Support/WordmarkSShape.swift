import SwiftUI

/// The Spill wordmark's "S" glyph outline, sampled from `Spill-web/web/public/favicon.svg`
/// and normalized to the unit square so it can be scaled into any frame. Kept as a fixed
/// point list (rather than re-derived curves) to stay pixel-faithful to the shipped brand
/// asset.
struct WordmarkSShape: Shape {
    static let points: [CGPoint] = [
        CGPoint(x: 0.2913, y: 0.9984), CGPoint(x: 0.2562, y: 1.0000), CGPoint(x: 0.2337, y: 0.9999), CGPoint(x: 0.2187, y: 0.9990),
        CGPoint(x: 0.1837, y: 0.9961), CGPoint(x: 0.1437, y: 0.9889), CGPoint(x: 0.1337, y: 0.9864), CGPoint(x: 0.1112, y: 0.9790),
        CGPoint(x: 0.0912, y: 0.9711), CGPoint(x: 0.0812, y: 0.9662), CGPoint(x: 0.0712, y: 0.9605), CGPoint(x: 0.0587, y: 0.9523),
        CGPoint(x: 0.0487, y: 0.9450), CGPoint(x: 0.0412, y: 0.9383), CGPoint(x: 0.0337, y: 0.9309), CGPoint(x: 0.0254, y: 0.9207),
        CGPoint(x: 0.0182, y: 0.9104), CGPoint(x: 0.0122, y: 0.9001), CGPoint(x: 0.0079, y: 0.8897), CGPoint(x: 0.0027, y: 0.8716),
        CGPoint(x: 0.0000, y: 0.8510), CGPoint(x: 0.0004, y: 0.8380), CGPoint(x: 0.0024, y: 0.8225), CGPoint(x: 0.0055, y: 0.8096),
        CGPoint(x: 0.0096, y: 0.7967), CGPoint(x: 0.0154, y: 0.7838), CGPoint(x: 0.0198, y: 0.7760), CGPoint(x: 0.0249, y: 0.7682),
        CGPoint(x: 0.0352, y: 0.7553), CGPoint(x: 0.0462, y: 0.7443), CGPoint(x: 0.0587, y: 0.7339), CGPoint(x: 0.0712, y: 0.7261),
        CGPoint(x: 0.0812, y: 0.7209), CGPoint(x: 0.0912, y: 0.7178), CGPoint(x: 0.1037, y: 0.7165), CGPoint(x: 0.1137, y: 0.7175),
        CGPoint(x: 0.1237, y: 0.7213), CGPoint(x: 0.1287, y: 0.7246), CGPoint(x: 0.1337, y: 0.7291), CGPoint(x: 0.1399, y: 0.7372),
        CGPoint(x: 0.1425, y: 0.7424), CGPoint(x: 0.1446, y: 0.7501), CGPoint(x: 0.1450, y: 0.7605), CGPoint(x: 0.1430, y: 0.7708),
        CGPoint(x: 0.1396, y: 0.7786), CGPoint(x: 0.1336, y: 0.7863), CGPoint(x: 0.1162, y: 0.8024), CGPoint(x: 0.1112, y: 0.8099),
        CGPoint(x: 0.1087, y: 0.8150), CGPoint(x: 0.1062, y: 0.8231), CGPoint(x: 0.1051, y: 0.8329), CGPoint(x: 0.1062, y: 0.8418),
        CGPoint(x: 0.1085, y: 0.8484), CGPoint(x: 0.1112, y: 0.8535), CGPoint(x: 0.1162, y: 0.8600), CGPoint(x: 0.1212, y: 0.8649),
        CGPoint(x: 0.1267, y: 0.8691), CGPoint(x: 0.1404, y: 0.8768), CGPoint(x: 0.1597, y: 0.8846), CGPoint(x: 0.1783, y: 0.8897),
        CGPoint(x: 0.2074, y: 0.8949), CGPoint(x: 0.2337, y: 0.8975), CGPoint(x: 0.2487, y: 0.8982), CGPoint(x: 0.2812, y: 0.8979),
        CGPoint(x: 0.3138, y: 0.8952), CGPoint(x: 0.3363, y: 0.8924), CGPoint(x: 0.3660, y: 0.8871), CGPoint(x: 0.3898, y: 0.8820),
        CGPoint(x: 0.4172, y: 0.8742), CGPoint(x: 0.4485, y: 0.8639), CGPoint(x: 0.4735, y: 0.8535), CGPoint(x: 0.4951, y: 0.8432),
        CGPoint(x: 0.5128, y: 0.8329), CGPoint(x: 0.5323, y: 0.8199), CGPoint(x: 0.5419, y: 0.8122), CGPoint(x: 0.5513, y: 0.8036),
        CGPoint(x: 0.5638, y: 0.7895), CGPoint(x: 0.5713, y: 0.7787), CGPoint(x: 0.5738, y: 0.7739), CGPoint(x: 0.5788, y: 0.7599),
        CGPoint(x: 0.5806, y: 0.7476), CGPoint(x: 0.5802, y: 0.7398), CGPoint(x: 0.5791, y: 0.7346), CGPoint(x: 0.5765, y: 0.7269),
        CGPoint(x: 0.5740, y: 0.7217), CGPoint(x: 0.5688, y: 0.7143), CGPoint(x: 0.5635, y: 0.7088), CGPoint(x: 0.5574, y: 0.7036),
        CGPoint(x: 0.5488, y: 0.6978), CGPoint(x: 0.5409, y: 0.6933), CGPoint(x: 0.5247, y: 0.6855), CGPoint(x: 0.5038, y: 0.6775),
        CGPoint(x: 0.4798, y: 0.6700), CGPoint(x: 0.4513, y: 0.6622), CGPoint(x: 0.4238, y: 0.6558), CGPoint(x: 0.3338, y: 0.6328),
        CGPoint(x: 0.2888, y: 0.6195), CGPoint(x: 0.2512, y: 0.6065), CGPoint(x: 0.2387, y: 0.6015), CGPoint(x: 0.2212, y: 0.5934),
        CGPoint(x: 0.1912, y: 0.5777), CGPoint(x: 0.1687, y: 0.5625), CGPoint(x: 0.1612, y: 0.5565), CGPoint(x: 0.1497, y: 0.5459),
        CGPoint(x: 0.1333, y: 0.5279), CGPoint(x: 0.1227, y: 0.5123), CGPoint(x: 0.1155, y: 0.4994), CGPoint(x: 0.1098, y: 0.4865),
        CGPoint(x: 0.1049, y: 0.4710), CGPoint(x: 0.1022, y: 0.4581), CGPoint(x: 0.0996, y: 0.4374), CGPoint(x: 0.0998, y: 0.4219),
        CGPoint(x: 0.1023, y: 0.4012), CGPoint(x: 0.1048, y: 0.3883), CGPoint(x: 0.1100, y: 0.3702), CGPoint(x: 0.1158, y: 0.3547),
        CGPoint(x: 0.1227, y: 0.3392), CGPoint(x: 0.1355, y: 0.3159), CGPoint(x: 0.1421, y: 0.3056), CGPoint(x: 0.1650, y: 0.2745),
        CGPoint(x: 0.1859, y: 0.2513), CGPoint(x: 0.1962, y: 0.2408), CGPoint(x: 0.2187, y: 0.2198), CGPoint(x: 0.2312, y: 0.2090),
        CGPoint(x: 0.2537, y: 0.1910), CGPoint(x: 0.2863, y: 0.1675), CGPoint(x: 0.3188, y: 0.1468), CGPoint(x: 0.3538, y: 0.1263),
        CGPoint(x: 0.3938, y: 0.1053), CGPoint(x: 0.4388, y: 0.0841), CGPoint(x: 0.4813, y: 0.0666), CGPoint(x: 0.5388, y: 0.0460),
        CGPoint(x: 0.6013, y: 0.0274), CGPoint(x: 0.6338, y: 0.0196), CGPoint(x: 0.6688, y: 0.0123), CGPoint(x: 0.6838, y: 0.0095),
        CGPoint(x: 0.7213, y: 0.0042), CGPoint(x: 0.7463, y: 0.0017), CGPoint(x: 0.7788, y: 0.0000), CGPoint(x: 0.8038, y: 0.0002),
        CGPoint(x: 0.8338, y: 0.0018), CGPoint(x: 0.8538, y: 0.0044), CGPoint(x: 0.8789, y: 0.0094), CGPoint(x: 0.8964, y: 0.0146),
        CGPoint(x: 0.9164, y: 0.0227), CGPoint(x: 0.9314, y: 0.0303), CGPoint(x: 0.9439, y: 0.0380), CGPoint(x: 0.9539, y: 0.0456),
        CGPoint(x: 0.9663, y: 0.0574), CGPoint(x: 0.9752, y: 0.0677), CGPoint(x: 0.9824, y: 0.0781), CGPoint(x: 0.9902, y: 0.0936),
        CGPoint(x: 0.9945, y: 0.1065), CGPoint(x: 0.9976, y: 0.1194), CGPoint(x: 0.9994, y: 0.1324), CGPoint(x: 1.0000, y: 0.1427),
        CGPoint(x: 0.9996, y: 0.1556), CGPoint(x: 0.9975, y: 0.1737), CGPoint(x: 0.9941, y: 0.1892), CGPoint(x: 0.9905, y: 0.2022),
        CGPoint(x: 0.9848, y: 0.2177), CGPoint(x: 0.9768, y: 0.2358), CGPoint(x: 0.9702, y: 0.2487), CGPoint(x: 0.9524, y: 0.2771),
        CGPoint(x: 0.9326, y: 0.3030), CGPoint(x: 0.9191, y: 0.3185), CGPoint(x: 0.8944, y: 0.3443), CGPoint(x: 0.8714, y: 0.3660),
        CGPoint(x: 0.8463, y: 0.3873), CGPoint(x: 0.8238, y: 0.4052), CGPoint(x: 0.7813, y: 0.4356), CGPoint(x: 0.7613, y: 0.4487),
        CGPoint(x: 0.7363, y: 0.4637), CGPoint(x: 0.7113, y: 0.4769), CGPoint(x: 0.7038, y: 0.4798), CGPoint(x: 0.6938, y: 0.4822),
        CGPoint(x: 0.6838, y: 0.4828), CGPoint(x: 0.6713, y: 0.4802), CGPoint(x: 0.6638, y: 0.4769), CGPoint(x: 0.6588, y: 0.4734),
        CGPoint(x: 0.6535, y: 0.4684), CGPoint(x: 0.6497, y: 0.4632), CGPoint(x: 0.6471, y: 0.4581), CGPoint(x: 0.6447, y: 0.4503),
        CGPoint(x: 0.6438, y: 0.4451), CGPoint(x: 0.6438, y: 0.4374), CGPoint(x: 0.6454, y: 0.4296), CGPoint(x: 0.6473, y: 0.4245),
        CGPoint(x: 0.6496, y: 0.4193), CGPoint(x: 0.6563, y: 0.4092), CGPoint(x: 0.6613, y: 0.4037), CGPoint(x: 0.6663, y: 0.3995),
        CGPoint(x: 0.6911, y: 0.3857), CGPoint(x: 0.7302, y: 0.3624), CGPoint(x: 0.7713, y: 0.3341), CGPoint(x: 0.8038, y: 0.3081),
        CGPoint(x: 0.8313, y: 0.2825), CGPoint(x: 0.8440, y: 0.2694), CGPoint(x: 0.8538, y: 0.2575), CGPoint(x: 0.8689, y: 0.2377),
        CGPoint(x: 0.8768, y: 0.2254), CGPoint(x: 0.8814, y: 0.2168), CGPoint(x: 0.8864, y: 0.2066), CGPoint(x: 0.8914, y: 0.1941),
        CGPoint(x: 0.8941, y: 0.1841), CGPoint(x: 0.8957, y: 0.1737), CGPoint(x: 0.8958, y: 0.1608), CGPoint(x: 0.8939, y: 0.1508),
        CGPoint(x: 0.8914, y: 0.1441), CGPoint(x: 0.8889, y: 0.1391), CGPoint(x: 0.8841, y: 0.1324), CGPoint(x: 0.8789, y: 0.1268),
        CGPoint(x: 0.8731, y: 0.1220), CGPoint(x: 0.8689, y: 0.1190), CGPoint(x: 0.8589, y: 0.1136), CGPoint(x: 0.8471, y: 0.1091),
        CGPoint(x: 0.8379, y: 0.1065), CGPoint(x: 0.8260, y: 0.1039), CGPoint(x: 0.8063, y: 0.1012), CGPoint(x: 0.7888, y: 0.1005),
        CGPoint(x: 0.7588, y: 0.1006), CGPoint(x: 0.7459, y: 0.1014), CGPoint(x: 0.7216, y: 0.1039), CGPoint(x: 0.7038, y: 0.1063),
        CGPoint(x: 0.6738, y: 0.1114), CGPoint(x: 0.6163, y: 0.1246), CGPoint(x: 0.5647, y: 0.1401), CGPoint(x: 0.5152, y: 0.1582),
        CGPoint(x: 0.4963, y: 0.1658), CGPoint(x: 0.4547, y: 0.1841), CGPoint(x: 0.4088, y: 0.2072), CGPoint(x: 0.3722, y: 0.2280),
        CGPoint(x: 0.3413, y: 0.2483), CGPoint(x: 0.3263, y: 0.2586), CGPoint(x: 0.3056, y: 0.2745), CGPoint(x: 0.2762, y: 0.3004),
        CGPoint(x: 0.2587, y: 0.3189), CGPoint(x: 0.2461, y: 0.3340), CGPoint(x: 0.2385, y: 0.3443), CGPoint(x: 0.2261, y: 0.3650),
        CGPoint(x: 0.2209, y: 0.3753), CGPoint(x: 0.2187, y: 0.3810), CGPoint(x: 0.2137, y: 0.3995), CGPoint(x: 0.2122, y: 0.4115),
        CGPoint(x: 0.2119, y: 0.4193), CGPoint(x: 0.2124, y: 0.4270), CGPoint(x: 0.2137, y: 0.4348), CGPoint(x: 0.2162, y: 0.4424),
        CGPoint(x: 0.2209, y: 0.4529), CGPoint(x: 0.2287, y: 0.4648), CGPoint(x: 0.2362, y: 0.4736), CGPoint(x: 0.2419, y: 0.4787),
        CGPoint(x: 0.2559, y: 0.4891), CGPoint(x: 0.2687, y: 0.4969), CGPoint(x: 0.2895, y: 0.5072), CGPoint(x: 0.3163, y: 0.5177),
        CGPoint(x: 0.3306, y: 0.5227), CGPoint(x: 0.3739, y: 0.5356), CGPoint(x: 0.4788, y: 0.5628), CGPoint(x: 0.5313, y: 0.5785),
        CGPoint(x: 0.5613, y: 0.5888), CGPoint(x: 0.5738, y: 0.5938), CGPoint(x: 0.6038, y: 0.6089), CGPoint(x: 0.6263, y: 0.6227),
        CGPoint(x: 0.6413, y: 0.6345), CGPoint(x: 0.6536, y: 0.6468), CGPoint(x: 0.6665, y: 0.6623), CGPoint(x: 0.6742, y: 0.6752),
        CGPoint(x: 0.6829, y: 0.6959), CGPoint(x: 0.6866, y: 0.7114), CGPoint(x: 0.6879, y: 0.7243), CGPoint(x: 0.6881, y: 0.7450),
        CGPoint(x: 0.6868, y: 0.7553), CGPoint(x: 0.6844, y: 0.7682), CGPoint(x: 0.6824, y: 0.7760), CGPoint(x: 0.6748, y: 0.7967),
        CGPoint(x: 0.6701, y: 0.8070), CGPoint(x: 0.6646, y: 0.8174), CGPoint(x: 0.6496, y: 0.8406), CGPoint(x: 0.6313, y: 0.8618),
        CGPoint(x: 0.6113, y: 0.8813), CGPoint(x: 0.5938, y: 0.8953), CGPoint(x: 0.5788, y: 0.9064), CGPoint(x: 0.5663, y: 0.9145),
        CGPoint(x: 0.5488, y: 0.9248), CGPoint(x: 0.5263, y: 0.9369), CGPoint(x: 0.5088, y: 0.9452), CGPoint(x: 0.4763, y: 0.9585),
        CGPoint(x: 0.4313, y: 0.9735), CGPoint(x: 0.3913, y: 0.9838), CGPoint(x: 0.3638, y: 0.9895), CGPoint(x: 0.3338, y: 0.9942),
        CGPoint(x: 0.3138, y: 0.9967),
    ]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = Self.points.first else { return path }
        path.move(to: CGPoint(x: rect.minX + rect.width * first.x, y: rect.minY + rect.height * first.y))
        for point in Self.points.dropFirst() {
            path.addLine(to: CGPoint(x: rect.minX + rect.width * point.x, y: rect.minY + rect.height * point.y))
        }
        path.closeSubpath()
        return path
    }
}
