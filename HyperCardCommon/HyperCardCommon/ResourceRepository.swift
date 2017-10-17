//
//  ResourceRepository.swift
//  HyperCard
//
//  Created by Pierre Lorenzi on 27/02/2017.
//  Copyright © 2017 Pierre Lorenzi. All rights reserved.
//



/// A resource fork, not as a raw data but as a typed data
public struct ResourceRepository {
    
    /// The resources. The Resource<> objects have not common superclass, so no type can be given to the array
    public var resources: [Any]    = []
    
    /// The repository representing the resource forks of HyperCard and Mac OS.
    public static let mainRepository = buildMainRepository()
    
}

private func buildMainRepository() -> ResourceRepository {
    
    var repository = ResourceRepository()
    
    /* Add the icons */
    let icons = loadIcons()
    repository.resources.append(contentsOf: icons)
    
    /* Add the fonts */
    let fonts = loadClassicFontResources()
    repository.resources.append(contentsOf: fonts)
    
    return repository
}

private func loadIcons() -> [Any] {
    
    /* Create the repository */
    var icons = [Any]()
    
    /* Add the icons */
    let iconIdentifiers = listIconIdentifiers()
    for iconIdentifier in iconIdentifiers {
        let icon = AppResourceIcon(identifier: iconIdentifier)
        icons.append(icon)
    }
    
    return icons
}

private class AppResourceIcon: Resource<Image> {
    // TODO no name for the icons?
    
    private static let fakeImage = Image(width: 0, height: 0)
    
    public init(identifier: Int) {
        super.init(identifier: identifier, name: "", type: ResourceTypes.icon, content: AppResourceIcon.fakeImage)
    }
    
    private var contentLoaded = false
    override public var content: Image {
        get {
            if !contentLoaded {
                super.content = loadIcon(withIdentifier: identifier)
                contentLoaded = true
            }
            return super.content
        }
        set {
            super.content = newValue
        }
    }
    
}

private let IconFilePrefix = "icon_"
private let IconPath = "Icons"

private func listIconIdentifiers() -> [Int] {
    
    /* Get the path of the icon directory */
    guard let resourcePath = HyperCardBundle.resourcePath else {
        return []
    }
    
    /* Load the file names */
    guard let fileNames = try? FileManager.`default`.contentsOfDirectory(atPath: resourcePath) else {
        return []
    }
    
    /* Find the icon identifiers */
    let iconFileNames = fileNames.filter({$0.hasPrefix(IconFilePrefix)})
    let iconIdentifiers = iconFileNames.flatMap({ (s: String) -> Int? in
        let scanner = Scanner(string: s)
        guard scanner.scanString(IconFilePrefix, into: nil) else {
            return nil
        }
        var result: Int32 = 0
        guard scanner.scanInt32(&result) else {
            print(s)
            return nil
        }
        return Int(result)
    })
    
    //TODO: peek at XCode assets, get asset names.
    var anidx = Set<Int>([-16412, -16480, -16487, -16488, -16489, -16490, -16491, -16492, -16500, -16522, -16523, -16524, -16525, -16526, -16527, -16557, -16560, -16561, -16563, -16565, -16570, -16573, -20183, -20184, -20185, -20275, -20534, -20542, -6079, 0, 1, 1000, 1001, 1002, 1003, 1004, 1005, 1006, 1007, 1008, 1009, 1011, 1012, 1013, 1014, 1015, 1016, 1017, 1018, 10181, 1019, 1020, 10610, 10935, 11045, 11216, 11260, 11645, 11714, 12195, 12411, 12722, 128, 129, 13149, 13744, 13745, 14767, 14953, 15279, 15420, 15972, 15993, 16321, 16344, 16560, 16692, 16735, 17169, 17214, 17264, 17343, 17357, 17481, 17779, 17838, 17890, 17896, 17937, 18222, 18223, 18607, 18814, 19162, 19381, 19638, 19678, 2, 2002, 20098, 20186, 20689, 20965, 2101, 2102, 2103, 2104, 2105, 2106, 21060, 21209, 21437, 21449, 21573, 21574, 21575, 21576, 2162, 21700, 21711, 2181, 21847, 22308, 22855, 22978, 23078, 2335, 23613, 23717, 23718, 24081, 24317, 24694, 24753, 2478, 24830, 25002, 2507, 25309, 26020, 26425, 26635, 26665, 26865, 26884, 27009, 27056, 2730, 27328, 27774, 27969, 28022, 28023, 28024, 28654, 28810, 28811, 29019, 29114, 29484, 29589, 2980, 29903, 30557, 30696, 3071, 31685, 31885, 32462, 32488, 32650, 32670, 3333, 3358, 3430, 3584, 3835, 4263, 4432, 4895, 5472, 6043, 6044, 6179, 6460, 6491, 6544, 6560, 6720, 6724, 7012, 7142, 7417, 766, 8323, 8347, 8348, 8349, 8350, 8419, 8538, 8961, 8964, 8979, 8980, 902, 9104, 9120, 9301, 9761])
    for iden in iconIdentifiers {
        anidx.insert(iden)
    }
    
    /*
    for i in -20542 ... -6079 {
        if let _ = HyperCardBundle.image(forResource: NSImage.Name(rawValue: "\(IconPath)/\(i)"))  {
            toAdd.insert(i)
        }
    }

    for i in 0 ... 32670 {
        if let _ = HyperCardBundle.image(forResource: NSImage.Name(rawValue: "\(IconPath)/\(i)"))  {
            toAdd.insert(i)
        }
    }*/
    
    return anidx.sorted()
}

private func loadIcon(withIdentifier identifier: Int) -> Image {
    
    /* Load the icon */
    let iconName = "\(IconPath)/\(identifier)"
    if let maskedImage = MaskedImage(named: iconName) {
        if case MaskedImage.Layer.bitmap(let image, _, _) = maskedImage.image {
            return image
        }
    }
    fatalError("loadIcon: can't find icon with identifier \(identifier)")
}

private let classicFontRepositoryNames: [String] = [
    "Athens",
    "Cairo",
    "Charcoal",
    "Chicago",
    "Courier",
    "Geneva",
    "Helvetica",
    "London",
    "Los Angeles",
    "Monaco",
    "New York",
    "Palatino",
    "San Francisco",
    "Symbol",
    "Times",
    "Venice",
    
    "Fonts"
]

private func loadClassicFontResources() -> [Any] {
    
    return classicFontRepositoryNames.flatMap(loadClassicFontResources).reduce([], { (a: [Any], b: [Any]) in a+b })
    
}

private func loadClassicFontResources(withName name: String) -> [Any]? {
    
    /* Get the path to file */
    guard let path = HyperCardBundle.path(forResource: name, ofType: "dfont") else {
        return nil
    }
    
    /* Load the file */
    let file = ClassicFile(path: path, loadResourcesFromDataFork: true)
    
    return file.resourceRepository?.resources
    
}


