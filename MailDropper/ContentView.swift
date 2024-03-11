//
//  ContentView.swift
//  MailDropper
//
//  Created by Mark Alldritt on 2024-03-11.
//

import SwiftUI
import UniformTypeIdentifiers
import MimeParser


extension MimeHeader {
    //  Convienence allowing subscript access into the MIME message header fields.
    
    subscript(index: String) -> RFC822HeaderField? {
       get
        {
            if let field = other.first(where: { field in
                return field.name == index
            }) {
                return field
            }
            
            return nil
        }
    }
}


struct ContentView: View {
    @State var message: String = "Drop Email Messages Here..."
    @State var targetted = false

    var body: some View {
        VStack {
            Text("Mail Dropper")
                .font(.largeTitle)
                .padding(20)
            
            Text(message)
                .padding(5)
            
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 60))
                .padding(100)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(targetted ? .green.opacity(0.3) : .clear)
        .contentShape(Rectangle())
        .onDrop(of: [.fileURL, .item], isTargeted: $targetted, perform: {
            providers, _ in
            
            message = ""
            providers.forEach { provider in
#if os(iOS)
                provider.loadFileRepresentation(forTypeIdentifier: UTType.item.identifier) { url, _ in
                    message += describeDroppedURL(url!)
                }
#else
                _ = provider.loadObject(ofClass: NSPasteboard.PasteboardType.self) { pasteboardItem, _ in
                    message += describeDroppedURL(URL(string: pasteboardItem!.rawValue)!)
                }
#endif
            }
            
            return true
        })
    }
}

func describeMIMEFile(_ url: URL) throws -> String {
    /*
    return "    which starts with `\((try String(contentsOf: url)).components(separatedBy: "\n")[0])`"
     */
    
    var object = [String:String]()
    let mime = try MimeParser().parse(try String(contentsOf: url))
    
    object["Body"] = try mime.decodedContentString()
    object["Date"] = mime.header["Date"]?.body ?? ""
    object["Subject"] = mime.header["Subject"]?.body ?? ""
    object["From"] = mime.header["From"]?.body ?? ""
    object["To"] = mime.header["To"]?.body ?? ""
    object["Message-ID"] = mime.header["Message-ID"]?.body ?? ""
    
    let jsonData = try JSONSerialization.data(withJSONObject: object)
    
    //  Just for testing, invoke a Shortcuts script to see if this works.  This all needs to be refactored into something people can use.

    let shortcutsURL = URL(string: "shortcuts://run-shortcut")!
    let shortcutName = URLQueryItem(name: "name", value: "Process Email")
    let input = URLQueryItem(name: "input", value: String(data: jsonData, encoding: .utf8))
    
    let url = shortcutsURL.appending(queryItems: [
        shortcutName,
        input
    ])

    DispatchQueue.main.async {
        if #available(iOS 10.0, *) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else {
            UIApplication.shared.openURL(url)
        }
    }

    return "JSON: \(String(data: jsonData, encoding: .utf8) ?? "")"
}

func describeDroppedURL(_ url: URL) -> String {
    do {
        var messageRows: [String] = []

        if try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == false {
            messageRows.append("Dropped file named `\(url.lastPathComponent)`")

            messageRows.append(try describeMIMEFile(url))
        } else {
            messageRows.append("Dropped folder named `\(url.lastPathComponent)`")

            for childUrl in try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: []) {
                messageRows.append("  Containing file named `\(childUrl.lastPathComponent)`")

                messageRows.append(try describeMIMEFile(childUrl))
            }
        }

        return messageRows.joined(separator: "\n")
    } catch {
        return "Error: \(error)"
    }
}


#Preview {
    ContentView()
}
