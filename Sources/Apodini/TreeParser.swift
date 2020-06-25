struct TreeParser {
    func parse(_ component: Any, indentation: Int = 0) {
        #warning("General problem/question: How can we print a \"Tree Like Structure\" of the components that we have in the View Tree? and interpert it the Best?")
        let mirror = Mirror(reflecting: component)
        
        
        for child in mirror.children {
            #warning("More concrete question: If iterating over the mirror's children is the right approach, how do we manage to cast the elements to be Components? Use Any and then cast back, is that a suitable approach?")
            if child.value is AnyComponent {
                
                printLabelAndBaseType(child, indentation: indentation)
                
                if let anyTupleComponent = child.value as? AnyTupleComponent {
                    for component in anyTupleComponent.components.enumerated() {
                        printLabel(component.offset.description,
                                   typeToBaseType: "\(component.element.self)",
                                   indentation: indentation + 1)
                        parse(component.element, indentation: indentation + 2)
                    }
                } else {
                    parse(child.value, indentation: indentation + 1)
                }
            } else {
                printLabelAndValue(child, indentation: indentation)
            }
        }
    }
    
    private func printLabelAndBaseType(_ child: Mirror.Child, indentation: Int) {
        printLabel(child.label ?? "UNKNOWN", typeToBaseType: String(describing: child.value), indentation: indentation)
    }
    
    private func printLabel(_ label: String, typeToBaseType: String, indentation: Int) {
        let baseType = typeToBaseType.components(separatedBy: "<").first ?? "UNKNOWN"
        print("\(String(repeating: "  ", count: indentation))\(label): \(baseType)")
    }
    
    private func printLabelAndValue(_ child: Mirror.Child, indentation: Int) {
        print("\(String(repeating: "  ", count: indentation))\(child.label ?? "UNKNOWN") = \(child.value)")
    }
}
