import CoreGraphics
import Foundation

protocol OpponentControlling {
    func desiredPaddleY(snapshot: PongSnapshot, dt: TimeInterval, metrics: PongMetrics) -> CGFloat
}

protocol PongMLPredicting {
    func predict(
        ballX: Double,
        ballY: Double,
        velX: Double,
        velY: Double,
        paddleY: Double,
        courtWidth: Double,
        courtHeight: Double
    ) -> Double?
}

/// Simple intercept AI. Used whenever a Core ML model is missing or fails.
struct TrackingOpponent: OpponentControlling {
    func desiredPaddleY(snapshot: PongSnapshot, dt: TimeInterval, metrics: PongMetrics) -> CGFloat {
        _ = dt
        let comingTowardAI = snapshot.ballVelocity.dx > 12
        let target: CGFloat
        if comingTowardAI {
            target = interceptY(snapshot: snapshot, metrics: metrics)
        } else {
            target = snapshot.courtSize.height / 2
        }
        return metrics.clampPaddleY(target)
    }

    func interceptY(snapshot: PongSnapshot, metrics: PongMetrics) -> CGFloat {
        let dx = metrics.aiPaddleX - snapshot.ballPosition.x
        guard snapshot.ballVelocity.dx > 8, dx > 0 else {
            return snapshot.ballPosition.y
        }
        let time = dx / snapshot.ballVelocity.dx
        let projected = snapshot.ballPosition.y + snapshot.ballVelocity.dy * time
        return reflect(y: projected, min: metrics.ballRadius, max: snapshot.courtSize.height - metrics.ballRadius)
    }

    func reflect(y: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        let span = max - min
        guard span > 0 else { return min }
        let period = span * 2
        var rel = (y - min).truncatingRemainder(dividingBy: period)
        if rel < 0 { rel += period }
        if rel > span { rel = period - rel }
        return min + rel
    }
}

/// Optional Core ML hook. Loads `PongOpponent` from the bundle when present;
/// otherwise the tracking opponent runs unchanged.
struct CoreMLOpponent: OpponentControlling {
    private let fallback = TrackingOpponent()
    private let predictor: (any PongMLPredicting)?

    init(predictor: (any PongMLPredicting)? = PongMLModelLoader.loadIfAvailable()) {
        self.predictor = predictor
    }

    func desiredPaddleY(snapshot: PongSnapshot, dt: TimeInterval, metrics: PongMetrics) -> CGFloat {
        if let predictor,
           let predicted = predictor.predict(
            ballX: Double(snapshot.ballPosition.x),
            ballY: Double(snapshot.ballPosition.y),
            velX: Double(snapshot.ballVelocity.dx),
            velY: Double(snapshot.ballVelocity.dy),
            paddleY: Double(snapshot.aiPaddleY),
            courtWidth: Double(snapshot.courtSize.width),
            courtHeight: Double(snapshot.courtSize.height)
           ) {
            return metrics.clampPaddleY(CGFloat(predicted))
        }
        return fallback.desiredPaddleY(snapshot: snapshot, dt: dt, metrics: metrics)
    }
}

enum PongMLModelLoader {
    static func loadIfAvailable() -> (any PongMLPredicting)? {
        #if canImport(CoreML)
        return CoreMLPongPredictor.loadFromBundle()
        #else
        return nil
        #endif
    }
}

#if canImport(CoreML)
import CoreML

struct CoreMLPongPredictor: PongMLPredicting {
    let model: MLModel

    static func loadFromBundle() -> CoreMLPongPredictor? {
        let bundle = Bundle.main
        let url = bundle.url(forResource: "PongOpponent", withExtension: "mlmodelc")
            ?? bundle.url(forResource: "PongOpponent", withExtension: "mlmodel")
        guard let url, let model = try? MLModel(contentsOf: url) else {
            return nil
        }
        return CoreMLPongPredictor(model: model)
    }

    func predict(
        ballX: Double,
        ballY: Double,
        velX: Double,
        velY: Double,
        paddleY: Double,
        courtWidth: Double,
        courtHeight: Double
    ) -> Double? {
        let values: [String: Double] = [
            "ballX": ballX,
            "ballY": ballY,
            "velX": velX,
            "velY": velY,
            "paddleY": paddleY,
            "courtWidth": courtWidth,
            "courtHeight": courtHeight,
            "ball_x": ballX,
            "ball_y": ballY,
            "vel_x": velX,
            "vel_y": velY,
            "paddle_y": paddleY
        ]

        var features: [String: MLFeatureValue] = [:]
        for (name, description) in model.modelDescription.inputDescriptionsByName {
            guard description.type == .double, let value = values[name] else {
                return nil
            }
            features[name] = MLFeatureValue(double: value)
        }

        guard let provider = try? MLDictionaryFeatureProvider(dictionary: features),
              let output = try? model.prediction(from: provider) else {
            return nil
        }

        for name in output.featureNames {
            if let feature = output.featureValue(for: name), feature.type == .double {
                return feature.doubleValue
            }
        }
        return nil
    }
}
#endif
