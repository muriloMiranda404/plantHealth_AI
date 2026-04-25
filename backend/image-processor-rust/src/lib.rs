use std::ffi::c_void;
use std::slice;

#[no_mangle]
pub extern "C" fn apply_grayscale(ptr: *mut c_void, len: usize) {
    let data = unsafe { slice::from_raw_parts_mut(ptr as *mut u8, len) };
    
    // Simples processamento de imagem: cada 4 bytes (RGBA) -> Cinza
    for chunk in data.chunks_mut(4) {
        if chunk.len() == 4 {
            let r = chunk[0] as u32;
            let g = chunk[1] as u32;
            let b = chunk[2] as u32;
            let gray = ((r + g + b) / 3) as u8;
            chunk[0] = gray;
            chunk[1] = gray;
            chunk[2] = gray;
        }
    }
}
