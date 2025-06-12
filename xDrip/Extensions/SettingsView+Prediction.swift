import Foundation
import SwiftUI

// MARK: - Prediction Settings Extension

extension SettingsView {
    
    /// Creates the prediction settings section for the settings view
    var predictionSettingsSection: some View {
        Section("Glucose Prediction") {
            
            // Enable/disable predictions
            Toggle("Enable Predictions", isOn: Binding(
                get: { UserDefaults.standard.predictionEnabled },
                set: { UserDefaults.standard.predictionEnabled = $0 }
            ))
            .help("Show predicted glucose values on the chart")
            
            if UserDefaults.standard.predictionEnabled {
                
                // Time horizon picker
                Picker("Prediction Time", selection: Binding(
                    get: { UserDefaults.standard.predictionTimeHorizon },
                    set: { UserDefaults.standard.predictionTimeHorizon = $0 }
                )) {
                    Text("15 minutes").tag(15)
                    Text("30 minutes").tag(30)
                    Text("45 minutes").tag(45)
                    Text("60 minutes").tag(60)
                }
                .help("How far into the future to predict glucose values")
                
                // Show confidence bands
                Toggle("Show Confidence Bands", isOn: Binding(
                    get: { UserDefaults.standard.showPredictionConfidence },
                    set: { UserDefaults.standard.showPredictionConfidence = $0 }
                ))
                .help("Show uncertainty bands around predictions")
                
                // Low glucose prediction section
                Section("Low Glucose Prediction") {
                    
                    Toggle("Enable Low Glucose Alerts", isOn: Binding(
                        get: { UserDefaults.standard.lowGlucosePredictionEnabled },
                        set: { UserDefaults.standard.lowGlucosePredictionEnabled = $0 }
                    ))
                    .help("Alert when low glucose is predicted")
                    
                    if UserDefaults.standard.lowGlucosePredictionEnabled {
                        
                        HStack {
                            Text("Low Threshold")
                            Spacer()
                            TextField("70", value: Binding(
                                get: { UserDefaults.standard.lowGlucosePredictionThreshold },
                                set: { UserDefaults.standard.lowGlucosePredictionThreshold = $0 }
                            ), format: .number)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 80)
                            Text(UserDefaults.standard.bloodGlucoseUnitIsMgDl ? "mg/dL" : "mmol/L")
                        }
                        .help("Glucose level below which to predict low alerts")
                    }
                }
            }
        }
    }
}

// MARK: - Prediction Configuration View

struct PredictionConfigurationView: View {
    
    @State private var predictionEnabled = UserDefaults.standard.predictionEnabled
    @State private var timeHorizon = UserDefaults.standard.predictionTimeHorizon
    @State private var showConfidence = UserDefaults.standard.showPredictionConfidence
    @State private var lowPredictionEnabled = UserDefaults.standard.lowGlucosePredictionEnabled
    @State private var lowThreshold = UserDefaults.standard.lowGlucosePredictionThreshold
    @State private var lineWidth = UserDefaults.standard.predictionLineWidth
    
    var body: some View {
        Form {
            Section(header: Text("Glucose Prediction Settings")) {
                
                Toggle("Enable Predictions", isOn: $predictionEnabled)
                    .onChange(of: predictionEnabled) { value in
                        UserDefaults.standard.predictionEnabled = value
                    }
                
                if predictionEnabled {
                    
                    Picker("Time Horizon", selection: $timeHorizon) {
                        Text("15 minutes").tag(15)
                        Text("30 minutes").tag(30)
                        Text("45 minutes").tag(45)
                        Text("60 minutes").tag(60)
                        Text("90 minutes").tag(90)
                        Text("120 minutes").tag(120)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: timeHorizon) { value in
                        UserDefaults.standard.predictionTimeHorizon = value
                    }
                    
                    HStack {
                        Text("Line Width")
                        Spacer()
                        Slider(value: $lineWidth, in: 1.0...5.0, step: 0.5) {
                            Text("Line Width")
                        }
                        Text("\(lineWidth, specifier: "%.1f")px")
                            .frame(width: 40)
                    }
                    .onChange(of: lineWidth) { value in
                        UserDefaults.standard.predictionLineWidth = value
                    }
                    
                    Toggle("Show Confidence Bands", isOn: $showConfidence)
                        .onChange(of: showConfidence) { value in
                            UserDefaults.standard.showPredictionConfidence = value
                        }
                }
            }
            
            Section(header: Text("Low Glucose Prediction")) {
                
                Toggle("Enable Low Glucose Alerts", isOn: $lowPredictionEnabled)
                    .onChange(of: lowPredictionEnabled) { value in
                        UserDefaults.standard.lowGlucosePredictionEnabled = value
                    }
                
                if lowPredictionEnabled {
                    
                    HStack {
                        Text("Alert Threshold")
                        Spacer()
                        TextField("Threshold", value: $lowThreshold, format: .number)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 80)
                            .onChange(of: lowThreshold) { value in
                                UserDefaults.standard.lowGlucosePredictionThreshold = value
                            }
                        Text(UserDefaults.standard.bloodGlucoseUnitIsMgDl ? "mg/dL" : "mmol/L")
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Alert Timing")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• Immediate: ≤15 minutes")
                            .font(.caption2)
                        Text("• Urgent: 15-30 minutes")
                            .font(.caption2)
                        Text("• Warning: 30-60 minutes")
                            .font(.caption2)
                        Text("• Watch: 1-4 hours")
                            .font(.caption2)
                    }
                    .padding(.top, 8)
                }
            }
            
            Section(header: Text("Information")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("About Glucose Prediction")
                        .font(.headline)
                    
                    Text("This feature uses mathematical models to predict future glucose values based on recent trends. Predictions become less accurate the further into the future they project.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("⚠️ Predictions are for informational purposes only and should not replace clinical judgment or established diabetes management protocols.")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Prediction Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

struct PredictionConfigurationView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PredictionConfigurationView()
        }
    }
}