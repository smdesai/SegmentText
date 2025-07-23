//
// SaT.swift
//
// This file was automatically generated and should not be edited.
//

import CoreML


/// Model Prediction Input Type
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
class SaTInput : MLFeatureProvider {

    /// input_ids as 1 by 512 matrix of 32-bit integers
    var input_ids: MLMultiArray

    /// attention_mask as 1 by 512 matrix of 32-bit integers
    var attention_mask: MLMultiArray

    var featureNames: Set<String> { ["input_ids", "attention_mask"] }

    func featureValue(for featureName: String) -> MLFeatureValue? {
        if featureName == "input_ids" {
            return MLFeatureValue(multiArray: input_ids)
        }
        if featureName == "attention_mask" {
            return MLFeatureValue(multiArray: attention_mask)
        }
        return nil
    }

    init(input_ids: MLMultiArray, attention_mask: MLMultiArray) {
        self.input_ids = input_ids
        self.attention_mask = attention_mask
    }

    convenience init(input_ids: MLShapedArray<Int32>, attention_mask: MLShapedArray<Int32>) {
        self.init(input_ids: MLMultiArray(input_ids), attention_mask: MLMultiArray(attention_mask))
    }

}


/// Model Prediction Output Type
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
class SaTOutput : MLFeatureProvider {

    /// Source provided by CoreML
    private let provider : MLFeatureProvider

    /// output as 1 × 512 × 1 3-dimensional array of 16-bit floats
    var output: MLMultiArray {
        provider.featureValue(for: "output")!.multiArrayValue!
    }

    /// output as 1 × 512 × 1 3-dimensional array of 16-bit floats
    #if (os(macOS) || targetEnvironment(macCatalyst)) && arch(x86_64)
    @available(macOS, unavailable)
    @available(macCatalyst, unavailable)
    #endif
    var outputShapedArray: MLShapedArray<Float16> {
        MLShapedArray<Float16>(output)
    }

    var featureNames: Set<String> {
        provider.featureNames
    }

    func featureValue(for featureName: String) -> MLFeatureValue? {
        provider.featureValue(for: featureName)
    }

    init(output: MLMultiArray) {
        self.provider = try! MLDictionaryFeatureProvider(dictionary: ["output" : MLFeatureValue(multiArray: output)])
    }

    init(features: MLFeatureProvider) {
        self.provider = features
    }
}


/// Class for model loading and prediction
@available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *)
class SaT {
    let model: MLModel

    /// URL of model assuming it was installed in the same bundle as this class
    class var urlOfModelInThisBundle : URL {
        return Bundle.main.url(forResource: "SaT", withExtension:"mlmodelc", subdirectory: "Resources")!
    }

    /**
        Construct SaT instance with an existing MLModel object.

        Usually the application does not use this initializer unless it makes a subclass of SaT.
        Such application may want to use `MLModel(contentsOfURL:configuration:)` and `SaT.urlOfModelInThisBundle` to create a MLModel object to pass-in.

        - parameters:
          - model: MLModel object
    */
    init(model: MLModel) {
        self.model = model
    }

    /**
        Construct a model with configuration

        - parameters:
           - configuration: the desired model configuration

        - throws: an NSError object that describes the problem
    */
    convenience init(configuration: MLModelConfiguration = MLModelConfiguration()) throws {
        try self.init(contentsOf: type(of:self).urlOfModelInThisBundle, configuration: configuration)
    }

    /**
        Construct SaT instance with explicit path to mlmodelc file
        - parameters:
           - modelURL: the file url of the model

        - throws: an NSError object that describes the problem
    */
    convenience init(contentsOf modelURL: URL) throws {
        try self.init(model: MLModel(contentsOf: modelURL))
    }

    /**
        Construct a model with URL of the .mlmodelc directory and configuration

        - parameters:
           - modelURL: the file url of the model
           - configuration: the desired model configuration

        - throws: an NSError object that describes the problem
    */
    convenience init(contentsOf modelURL: URL, configuration: MLModelConfiguration) throws {
        try self.init(model: MLModel(contentsOf: modelURL, configuration: configuration))
    }

    /**
        Construct SaT instance asynchronously with optional configuration.

        Model loading may take time when the model content is not immediately available (e.g. encrypted model). Use this factory method especially when the caller is on the main thread.

        - parameters:
          - configuration: the desired model configuration
          - handler: the completion handler to be called when the model loading completes successfully or unsuccessfully
    */
    class func load(configuration: MLModelConfiguration = MLModelConfiguration(), completionHandler handler: @escaping (Swift.Result<SaT, Error>) -> Void) {
        load(contentsOf: self.urlOfModelInThisBundle, configuration: configuration, completionHandler: handler)
    }

    /**
        Construct SaT instance asynchronously with optional configuration.

        Model loading may take time when the model content is not immediately available (e.g. encrypted model). Use this factory method especially when the caller is on the main thread.

        - parameters:
          - configuration: the desired model configuration
    */
    class func load(configuration: MLModelConfiguration = MLModelConfiguration()) async throws -> SaT {
        try await load(contentsOf: self.urlOfModelInThisBundle, configuration: configuration)
    }

    /**
        Construct SaT instance asynchronously with URL of the .mlmodelc directory with optional configuration.

        Model loading may take time when the model content is not immediately available (e.g. encrypted model). Use this factory method especially when the caller is on the main thread.

        - parameters:
          - modelURL: the URL to the model
          - configuration: the desired model configuration
          - handler: the completion handler to be called when the model loading completes successfully or unsuccessfully
    */
    class func load(contentsOf modelURL: URL, configuration: MLModelConfiguration = MLModelConfiguration(), completionHandler handler: @escaping (Swift.Result<SaT, Error>) -> Void) {
        MLModel.load(contentsOf: modelURL, configuration: configuration) { result in
            switch result {
            case .failure(let error):
                handler(.failure(error))
            case .success(let model):
                handler(.success(SaT(model: model)))
            }
        }
    }

    /**
        Construct SaT instance asynchronously with URL of the .mlmodelc directory with optional configuration.

        Model loading may take time when the model content is not immediately available (e.g. encrypted model). Use this factory method especially when the caller is on the main thread.

        - parameters:
          - modelURL: the URL to the model
          - configuration: the desired model configuration
    */
    class func load(contentsOf modelURL: URL, configuration: MLModelConfiguration = MLModelConfiguration()) async throws -> SaT {
        let model = try await MLModel.load(contentsOf: modelURL, configuration: configuration)
        return SaT(model: model)
    }

    /**
        Make a prediction using the structured interface

        It uses the default function if the model has multiple functions.

        - parameters:
           - input: the input to the prediction as SaTInput

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as SaTOutput
    */
    func prediction(input: SaTInput) throws -> SaTOutput {
        try prediction(input: input, options: MLPredictionOptions())
    }

    /**
        Make a prediction using the structured interface

        It uses the default function if the model has multiple functions.

        - parameters:
           - input: the input to the prediction as SaTInput
           - options: prediction options

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as SaTOutput
    */
    func prediction(input: SaTInput, options: MLPredictionOptions) throws -> SaTOutput {
        let outFeatures = try model.prediction(from: input, options: options)
        return SaTOutput(features: outFeatures)
    }

    /**
        Make an asynchronous prediction using the structured interface

        It uses the default function if the model has multiple functions.

        - parameters:
           - input: the input to the prediction as SaTInput
           - options: prediction options

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as SaTOutput
    */
    func prediction(input: SaTInput, options: MLPredictionOptions = MLPredictionOptions()) async throws -> SaTOutput {
        let outFeatures = try await model.prediction(from: input, options: options)
        return SaTOutput(features: outFeatures)
    }

    /**
        Make a prediction using the convenience interface

        It uses the default function if the model has multiple functions.

        - parameters:
            - input_ids: 1 by 512 matrix of 32-bit integers
            - attention_mask: 1 by 512 matrix of 32-bit integers

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as SaTOutput
    */
    func prediction(input_ids: MLMultiArray, attention_mask: MLMultiArray) throws -> SaTOutput {
        let input_ = SaTInput(input_ids: input_ids, attention_mask: attention_mask)
        return try prediction(input: input_)
    }

    /**
        Make a prediction using the convenience interface

        It uses the default function if the model has multiple functions.

        - parameters:
            - input_ids: 1 by 512 matrix of 32-bit integers
            - attention_mask: 1 by 512 matrix of 32-bit integers

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as SaTOutput
    */

    func prediction(input_ids: MLShapedArray<Int32>, attention_mask: MLShapedArray<Int32>) throws -> SaTOutput {
        let input_ = SaTInput(input_ids: input_ids, attention_mask: attention_mask)
        return try prediction(input: input_)
    }

    /**
        Make a batch prediction using the structured interface

        It uses the default function if the model has multiple functions.

        - parameters:
           - inputs: the inputs to the prediction as [SaTInput]
           - options: prediction options

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as [SaTOutput]
    */
    func predictions(inputs: [SaTInput], options: MLPredictionOptions = MLPredictionOptions()) throws -> [SaTOutput] {
        let batchIn = MLArrayBatchProvider(array: inputs)
        let batchOut = try model.predictions(from: batchIn, options: options)
        var results : [SaTOutput] = []
        results.reserveCapacity(inputs.count)
        for i in 0..<batchOut.count {
            let outProvider = batchOut.features(at: i)
            let result =  SaTOutput(features: outProvider)
            results.append(result)
        }
        return results
    }
}
