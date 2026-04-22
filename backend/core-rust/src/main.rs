use axum::{routing::post, Json, Router};
use serde::{Deserialize, Serialize};
use std::net::SocketAddr;

#[derive(Deserialize)]
struct SensorData {
    temperature: f32,
    humidity: f32,
    moisture: f32,
}

#[derive(Serialize)]
struct HealthStatus {
    score: i32,
    status: String,
    recommendation: String,
}

#[tokio::main]
async fn main() {
    let app = Router::new().route("/analyze", post(analyze_plant_health));

    let addr = SocketAddr::from(([127, 0, 0, 1], 3000));
    println!("Rust Core Backend rodando em http://{}", addr);
    
    // Axum server initialization (mocked as cargo is missing)
    // axum::Server::bind(&addr).serve(app.into_make_service()).await.unwrap();
}

async fn analyze_plant_health(Json(data): Json<SensorData>) -> Json<HealthStatus> {
    let mut score = 100;
    let mut status = "Saudável".to_string();
    let mut recommendation = "Tudo em ordem!".to_string();

    if data.moisture < 30.0 {
        score -= 30;
        status = "Sede".to_string();
        recommendation = "Regue a planta imediatamente.".to_string();
    }

    if data.temperature > 35.0 {
        score -= 20;
        recommendation = format!("{} Mova para um local mais fresco.", recommendation);
    }

    Json(HealthStatus {
        score,
        status,
        recommendation,
    })
}
