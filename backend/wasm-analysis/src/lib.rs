use wasm_bindgen::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize)]
pub struct PlantData {
    pub moisture: f64,
    pub temperature: f64,
    pub humidity: f64,
}

#[derive(Serialize)]
pub struct AnalysisResult {
    pub health_score: i32,
    pub recommendation: String,
    pub water_needed_ml: f64,
}

#[wasm_bindgen]
pub fn analyze_plant_status(js_data: JsValue) -> JsValue {
    let data: PlantData = serde_wasm_bindgen::from_value(js_data).unwrap_or(PlantData {
        moisture: 50.0,
        temperature: 25.0,
        humidity: 50.0,
    });

    let mut score = 100;
    let mut recommendation = "Planta em ótimas condições!".to_string();
    let mut water_needed = 0.0;

    if data.moisture < 30.0 {
        score -= 40;
        recommendation = "Umidade crítica! Regue agora.".to_string();
        water_needed = 250.0;
    } else if data.moisture < 50.0 {
        score -= 10;
        recommendation = "Solo levemente seco. Considere regar em breve.".to_string();
        water_needed = 100.0;
    }

    if data.temperature > 35.0 {
        score -= 20;
        recommendation = format!("{} Temperatura muito alta, mova para a sombra.", recommendation);
    }

    let result = AnalysisResult {
        health_score: score,
        recommendation,
        water_needed_ml: water_needed,
    };

    serde_wasm_bindgen::to_value(&result).unwrap()
}
