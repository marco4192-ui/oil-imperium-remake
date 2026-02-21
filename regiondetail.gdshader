shader_type canvas_item;

// Zugriff auf den Bildschirminhalt dahinter
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// Einstellungen für den Retro-Look
uniform float scanline_count : hint_range(0, 1200) = 180.0; // Weniger Lines für Retro-Feeling
uniform float scanline_opacity : hint_range(0, 1) = 0.2; // Etwas transparenter
uniform float warp_amount : hint_range(0, 5) = 0.02; // Leichte Wölbung
uniform float vignette_intensity : hint_range(0, 5) = 0.3;
uniform float vignette_opacity : hint_range(0, 1) = 0.2; // Weniger Dunkelheit am Rand
uniform float aberration_amount : hint_range(0, 5) = 0.02;

vec2 warp(vec2 uv) {
	vec2 dc = abs(0.5 - uv);
	dc *= dc;
	return uv + vec2(0.0) * dc.y * dc.y; // Krümmung nur Vertikal leicht
}

void fragment() {
	vec2 uv = warp(SCREEN_UV);
	
	// Rand schwarz machen
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		// Farben lesen (Chromatische Aberration)
		float r = texture(screen_texture, uv + vec2(aberration_amount * 0.003, 0.0)).r;
		float g = texture(screen_texture, uv).g;
		float b = texture(screen_texture, uv - vec2(aberration_amount * 0.003, 0.0)).b;
		
		vec3 color = vec3(r, g, b);
		
		// Scanlines (Sinus-Welle)
		float s = sin(uv.y * scanline_count * 3.14159 * 2.0);
		s = (s * 0.5 + 0.5) * 0.9 + 0.1;
		vec3 scanline = vec3(pow(s, scanline_opacity));
		
		// Vignette
		float val = distance(uv, vec2(0.5));
		float vign = smoothstep(0.3, 0.8, val * vignette_intensity);
		
		// Mixen: Farbe * Scanline * Helligkeit - Vignette
		// Wir hellen das Bild leicht auf (1.1), damit es durch Scanlines nicht zu dunkel wird
		vec3 final_color = color * scanline * 1.1;
		final_color = mix(final_color, vec3(0.0), vign * vignette_opacity);
		
		COLOR = vec4(final_color, 1.0);
	}
}