import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "cpu")
                .font(.system(size: 48))
                .foregroundColor(.blue)
            
            Text("GPU Monitor Widget")
                .font(.title)
                .fontWeight(.semibold)
            
            Text("Add the widget to your Desktop or Notification Center")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Divider()
                .padding(.vertical, 8)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("To add the widget:")
                    .font(.headline)
                
                Text("1. Right-click on your Desktop")
                Text("2. Select \"Edit Widgets...\"")
                Text("3. Find \"GPU Monitor\" and drag it to your Desktop")
            }
            .font(.callout)
            .foregroundColor(.secondary)
        }
        .padding(32)
        .frame(width: 400, height: 300)
        .preferredColorScheme(.dark)
    }
}
