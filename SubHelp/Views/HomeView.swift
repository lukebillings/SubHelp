import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: HomeViewModel

    var body: some View {
        // Blank home screen – ready for subscription list UI
        Text("SubHelp")
            .font(.largeTitle)
    }
}

#Preview {
    HomeView(viewModel: HomeViewModel())
}
