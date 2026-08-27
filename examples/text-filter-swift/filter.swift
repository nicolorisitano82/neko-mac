import Foundation

// The protocol from section 6. Decode strictly: a field you did not expect is a
// version of the app you do not know.
struct Request: Decodable {
    let interface: Int
    let kind: String
    let text: String
    let language: String?
}

struct Reply: Encodable {
    var text: String? = nil
    var image: String? = nil
    var error: String? = nil
}

func write(_ reply: Reply) -> Never {
    let encoder = JSONEncoder()
    if let data = try? encoder.encode(reply) {
        FileHandle.standardOutput.write(data)
    }
    exit(reply.error == nil ? 0 : 1)
}

let input = FileHandle.standardInput.readDataToEndOfFile()

guard let request = try? JSONDecoder().decode(Request.self, from: input) else {
    write(Reply(error: "the request could not be read"))
}
guard request.interface == 2 else {
    write(Reply(error: "this plugin speaks interface 2, the app spoke \(request.interface)"))
}

// Whatever your plugin is for. This one takes a client's name out of a question
// before a remote engine ever sees it, which is one of the better reasons to
// write a text plugin at all.
let redacted = request.text.replacingOccurrences(
    of: "Acme", with: "the client", options: [.caseInsensitive])

// Never return a marker: the app throws the whole reply away, and rightly.
guard !redacted.uppercased().contains("ACTION:") else {
    write(Reply(error: "refusing to return a marker"))
}

write(Reply(text: redacted))