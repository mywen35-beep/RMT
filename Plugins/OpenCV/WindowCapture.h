#pragma once

#define _SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS
#include <roapi.h>
#include <d3d11.h>
#include <windows.graphics.capture.interop.h>
#include <windows.graphics.directx.direct3d11.interop.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Graphics.Capture.h>
#include <winrt/Windows.Graphics.DirectX.Direct3D11.h>
#pragma comment(lib, "d3d11.lib")
#pragma comment(lib, "windowsapp.lib")

// WGC reads the composed GPU surface, including emulator child swap chains.
// Close sessions inside the call, before thread/DLL teardown enters the loader lock.
class WindowCapture {
    using Item = winrt::Windows::Graphics::Capture::GraphicsCaptureItem;
    using Pool = winrt::Windows::Graphics::Capture::Direct3D11CaptureFramePool;
    using Session = winrt::Windows::Graphics::Capture::GraphicsCaptureSession;
    using Device = winrt::Windows::Graphics::DirectX::Direct3D11::IDirect3DDevice;
    HWND hwnd_ = nullptr;
    DWORD pid_ = 0;
    winrt::com_ptr<ID3D11Device> device_;
    winrt::com_ptr<ID3D11DeviceContext> context_;
    Device runtimeDevice_{ nullptr };
    Item item_{ nullptr };
    Pool pool_{ nullptr };
    Session session_{ nullptr };
    winrt::Windows::Graphics::SizeInt32 size_{};

    void Close() noexcept {
        try { if (session_) session_.Close(); } catch (...) {}
        try { if (pool_) pool_.Close(); } catch (...) {}
        session_ = nullptr;
        pool_ = nullptr;
        item_ = nullptr;
        hwnd_ = nullptr;
    }

public:
    ~WindowCapture() { Close(); }

    cv::Mat Capture(HWND hwnd, const RECT& roi) {
        try {
            if (!Session::IsSupported() || IsIconic(hwnd)) return {};
            DWORD pid = 0;
            GetWindowThreadProcessId(hwnd, &pid);
            if (!session_ || hwnd_ != hwnd || pid_ != pid) {
                Close();
                if (!device_) {
                    winrt::check_hresult(D3D11CreateDevice(nullptr, D3D_DRIVER_TYPE_HARDWARE,
                        nullptr, D3D11_CREATE_DEVICE_BGRA_SUPPORT, nullptr, 0,
                        D3D11_SDK_VERSION, device_.put(), nullptr, context_.put()));
                    auto dxgi = device_.as<IDXGIDevice>();
                    winrt::com_ptr<IInspectable> inspectable;
                    winrt::check_hresult(CreateDirect3D11DeviceFromDXGIDevice(dxgi.get(), inspectable.put()));
                    runtimeDevice_ = inspectable.as<Device>();
                }
                auto interop = winrt::get_activation_factory<Item, IGraphicsCaptureItemInterop>();
                winrt::check_hresult(interop->CreateForWindow(hwnd,
                    winrt::guid_of<Item>(), winrt::put_abi(item_)));
                size_ = item_.Size();
                pool_ = Pool::CreateFreeThreaded(runtimeDevice_,
                    winrt::Windows::Graphics::DirectX::DirectXPixelFormat::B8G8R8A8UIntNormalized,
                    2, size_);
                session_ = pool_.CreateCaptureSession(item_);
                try { session_.IsCursorCaptureEnabled(false); } catch (...) {}
                session_.StartCapture();
                hwnd_ = hwnd;
                pid_ = pid;
            }

            // Free-threaded pool needs no UI message pump. Bound all frame waits.
            const ULONGLONG deadline = GetTickCount64() + 250;
            do {
                auto frame = pool_.TryGetNextFrame();
                if (!frame) { Sleep(2); continue; }
                // Prefer the newest queued frame when the caller searches slowly.
                for (int i = 0; i < 2; ++i) {
                    auto newer = pool_.TryGetNextFrame();
                    if (!newer) break;
                    frame.Close();
                    frame = std::move(newer);
                }
                const auto content = frame.ContentSize();
                if (content.Width != size_.Width || content.Height != size_.Height) {
                    frame.Close();
                    size_ = content;
                    if (size_.Width <= 0 || size_.Height <= 0) return {};
                    pool_.Recreate(runtimeDevice_,
                        winrt::Windows::Graphics::DirectX::DirectXPixelFormat::B8G8R8A8UIntNormalized,
                        2, size_);
                    continue;
                }
                RECT bounds{};
                if (FAILED(DwmGetWindowAttribute(hwnd, DWMWA_EXTENDED_FRAME_BOUNDS,
                    &bounds, sizeof(bounds)))) return {};
                // Never scale a frame to fit: that reintroduces title/frame offsets.
                if (bounds.right - bounds.left != content.Width || bounds.bottom - bounds.top != content.Height) {
                    if (!GetWindowRect(hwnd, &bounds) || bounds.right - bounds.left != content.Width
                        || bounds.bottom - bounds.top != content.Height) return {};
                }
                POINT origin{};
                if (!ClientToScreen(hwnd, &origin)) return {};
                const int left = origin.x - bounds.left + roi.left;
                const int top = origin.y - bounds.top + roi.top;
                const int width = roi.right - roi.left, height = roi.bottom - roi.top;
                if (left < 0 || top < 0 || left + width > content.Width || top + height > content.Height)
                    return {};

                auto access = frame.Surface().as<Windows::Graphics::DirectX::Direct3D11::IDirect3DDxgiInterfaceAccess>();
                winrt::com_ptr<ID3D11Texture2D> texture;
                winrt::check_hresult(access->GetInterface(__uuidof(ID3D11Texture2D), texture.put_void()));
                D3D11_TEXTURE2D_DESC desc{};
                texture->GetDesc(&desc);
                desc.Width = width;
                desc.Height = height;
                desc.Usage = D3D11_USAGE_STAGING;
                desc.BindFlags = 0;
                desc.MiscFlags = 0;
                desc.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
                winrt::com_ptr<ID3D11Texture2D> staging;
                winrt::check_hresult(device_->CreateTexture2D(&desc, nullptr, staging.put()));
                D3D11_BOX box{ static_cast<UINT>(left), static_cast<UINT>(top), 0,
                    static_cast<UINT>(left + width), static_cast<UINT>(top + height), 1 };
                context_->CopySubresourceRegion(staging.get(), 0, 0, 0, 0, texture.get(), 0, &box);
                D3D11_MAPPED_SUBRESOURCE mapped{};
                winrt::check_hresult(context_->Map(staging.get(), 0, D3D11_MAP_READ, 0, &mapped));
                cv::Mat result;
                try { result = cv::Mat(height, width, CV_8UC4, mapped.pData, mapped.RowPitch).clone(); }
                catch (...) { context_->Unmap(staging.get(), 0); throw; }
                context_->Unmap(staging.get(), 0);
                frame.Close();
                return result;
            } while (GetTickCount64() < deadline);
        } catch (...) {
            Close();
        }
        return {};
    }
};

static cv::Mat CaptureGpuWindow(HWND hwnd, const RECT& roi) {
    // Sessions close before COM teardown, both outside the DLL loader lock.
    struct Apartment {
        HRESULT result = RoInitialize(RO_INIT_MULTITHREADED);
        ~Apartment() { if (SUCCEEDED(result)) RoUninitialize(); }
    };
    Apartment apartment;
    if (FAILED(apartment.result) && apartment.result != RPC_E_CHANGED_MODE) return {};
    WindowCapture capture;
    return capture.Capture(hwnd, roi);
}
