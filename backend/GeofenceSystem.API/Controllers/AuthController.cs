using GeofenceSystem.Application.Interfaces;
using Microsoft.AspNetCore.Mvc;

namespace GeofenceSystem.API.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class AuthController : ControllerBase
    {
        private readonly IAuthService _authService;

        public AuthController(IAuthService authService)
        {
            _authService = authService;
        }

        [HttpPost("register")]
        public async Task<IActionResult> Register([FromBody] RegisterRequest request)
        {
            var result = await _authService.Register(request.Email, request.Password, request.FullName);
            if (!result.success)
            {
                return BadRequest(new { Message = result.error });
            }

            return Ok(new { Message = "Usuario registrado exitosamente." });
        }

        [HttpPost("login")]
        public async Task<IActionResult> Login([FromBody] LoginRequest request)
        {
            var result = await _authService.Login(request.Email, request.Password);
            if (!result.success)
            {
                return Unauthorized(new { Message = result.error });
            }

            return Ok(new { Token = result.token });
        }
    }

    public record RegisterRequest(string Email, string Password, string FullName);
    public record LoginRequest(string Email, string Password);
}
