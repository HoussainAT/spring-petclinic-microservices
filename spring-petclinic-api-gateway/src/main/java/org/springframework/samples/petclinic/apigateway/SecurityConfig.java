package org.springframework.samples.petclinic.apigateway;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.reactive.EnableWebFluxSecurity;
import org.springframework.security.config.web.server.ServerHttpSecurity;
import org.springframework.security.core.userdetails.MapReactiveUserDetailsService;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.web.server.SecurityWebFilterChain;
import org.springframework.security.web.server.header.XFrameOptionsServerHttpHeadersWriter.Mode;

@Configuration
@EnableWebFluxSecurity
public class SecurityConfig {

    @Bean
    public SecurityWebFilterChain securityWebFilterChain(ServerHttpSecurity http) {
        return http
            .authorizeExchange(exchanges -> exchanges
                // Actuator: only health and info are public
                .pathMatchers("/actuator/health", "/actuator/info").permitAll()
                // All other actuator endpoints require ADMIN role
                .pathMatchers("/actuator/**").hasRole("ADMIN")
                // Static resources and UI routes are public
                .pathMatchers("/", "/index.html", "/css/**", "/js/**", "/images/**", "/favicon.ico").permitAll()
                // All other requests require authentication
                .anyExchange().authenticated()
            )
            .httpBasic(basic -> {})
            .csrf(ServerHttpSecurity.CsrfSpec::disable)
            .headers(headers -> headers
                .frameOptions(frame -> frame.mode(Mode.DENY))
                .contentSecurityPolicy(csp -> csp.policyDirectives("default-src 'self'"))
            )
            .build();
    }

    @Bean
    public MapReactiveUserDetailsService userDetailsService() {
        UserDetails admin = User.withDefaultPasswordEncoder()
            .username("admin")
            .password("changeme-in-prod")
            .roles("ADMIN")
            .build();
        return new MapReactiveUserDetailsService(admin);
    }
}
