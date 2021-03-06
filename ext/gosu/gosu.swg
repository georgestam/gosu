// Mini SWIG file TODO List:
// - %predicate instead of %rename where applicable
// - use Python names for op overloading for easier porting to other languages

%trackobjects;
%include exception.i  

// Don't complain about ignored operators.
#pragma SWIG nowarn=378

// The docs make it seem like this is a generally good idea.
%feature("compactdefaultargs");

// Overriding virtuals is necessary in Gosu::Window.
%feature("director") Gosu::Window;

// Overriding virtuals is necessary in Gosu::TextInput.
%feature("director") Gosu::TextInput;

// Resolve typedefs that SWIG doesn't recognize.
%apply unsigned char { std::tr1::uint8_t };
%apply unsigned long { std::tr1::uint32_t };

// Custom typemaps for wchar/wstring.
#pragma SWIG nowarn=-490,-319
%typemap(in) wchar_t {
    VALUE rbString = rb_obj_as_string($input);
    char* utf8String = StringValueCStr(rbString);
    std::wstring ucsString = Gosu::utf8ToWstring(utf8String);
    if (ucsString.length() != 1)
        rb_raise(rb_eArgError,
                 "A single-character string was expected, but `%s' given",
                 utf8String);
    
    $1 = ucsString[0];
}
%typemap(out) wchar_t {
    if ($1 == 0)
        $result = Qnil;
    else
    {
        $result = rb_str_new2(Gosu::wstringToUTF8(std::wstring(1, $1)).c_str());
        FIX_ENCODING($result);
    }
}
%typemap(in) const std::wstring& (std::wstring temp) {
    VALUE localTemporary = rb_obj_as_string($input);
    temp = Gosu::utf8ToWstring(StringValueCStr(localTemporary));
    $1 = &temp;
}
%typemap(typecheck) const std::wstring& {
    $1 = !!rb_respond_to($input, rb_intern("to_str"));
}
%apply const std::wstring& { std::wstring, const std::string };
%typemap(out) std::wstring {
    $result = rb_str_new2(Gosu::wstringToUTF8($1).c_str());
    FIX_ENCODING($result);
}
%typemap(out) const std::wstring& {
    $result = rb_str_new2(Gosu::wstringToUTF8($1).c_str());
    FIX_ENCODING($result);
}
%typemap(directorin) const std::wstring& {
    $input = rb_str_new2(Gosu::wstringToUTF8($1).c_str());
    FIX_ENCODING($input);
}
%typemap(directorout) std::wstring {
    VALUE localTemporary = rb_obj_as_string($1);
    $result = Gosu::utf8ToWstring(StringValueCStr(localTemporary));;
}
%typemap(out) std::string {
    $result = rb_str_new2($1.c_str());
    FIX_ENCODING($result);
}

%typemap(in) Gosu::Button {
    if (NIL_P($input))
        $1 = Gosu::noButton;
    else
        $1 = Gosu::Button(NUM2LONG($input));
}
%typemap(out) Gosu::Button {
    if ($1 == Gosu::noButton)
        $result = Qnil;
    else
        $result = LONG2NUM($1.id());
}
%typemap(directorin) Gosu::Button {
    if ($1 == Gosu::noButton)
        $input = Qnil;
    else
        $input = LONG2NUM($1.id());
}

// Typemaps for enums that should be given in as symbols.
%typemap(in) Gosu::AlphaMode {
    const char* cstr = Gosu::cstrFromSymbol($input);
    
    if (!strcmp(cstr, "default"))
        $1 = Gosu::amDefault;
    else if (!strcmp(cstr, "add"))
        $1 = Gosu::amAdditive;
    else if (!strcmp(cstr, "additive"))
        $1 = Gosu::amAdditive;
    else if (!strcmp(cstr, "multiply"))
        $1 = Gosu::amMultiply;
    else
        SWIG_exception_fail(SWIG_ValueError, "invalid alpha mode");
}
%typemap(in) Gosu::TextAlign {
    const char* cstr = Gosu::cstrFromSymbol($input);

    if (!strcmp(cstr, "left"))
        $1 = Gosu::taLeft;
    else if (!strcmp(cstr, "center"))
        $1 = Gosu::taCenter;
    else if (!strcmp(cstr, "right"))
        $1 = Gosu::taRight;
    else if (!strcmp(cstr, "justify"))
        $1 = Gosu::taJustify;
    else
        SWIG_exception_fail(SWIG_ValueError, "invalid text alignment (expected one of :left, :center, :right, :justify)");
}

// Allow integral constants to be passed in place of Color values.
%typemap(in) Gosu::Color {    
    if (TYPE($input) == T_FIXNUM || TYPE($input) == T_BIGNUM)
        $1 = Gosu::Color(NUM2ULONG($input));
    else
    {
        void* ptr;
        int res = SWIG_ConvertPtr($input, &ptr, SWIGTYPE_p_Gosu__Color, 0);
        if (!SWIG_IsOK(res))
            SWIG_exception_fail(SWIG_ValueError, "invalid value");
        else if (!ptr)
            SWIG_exception_fail(SWIG_ValueError, "invalid null reference of type Gosu::Color");
        else
            $1 = *reinterpret_cast<Gosu::Color*>(ptr);
    }
}

// Make color channels less strict.
%typemap(in) Gosu::Color::Channel {
    $1 = Gosu::clamp<int>(NUM2ULONG($input), 0, 255);
}
// To allow for overloading with Channel values.
%typemap(typecheck) Gosu::Color::Channel {
    $1 = !!rb_respond_to($input, rb_intern("to_i"));
}

// Header inclusion (order irrelevant)
%module(directors="1") gosu
%{
    
// Escape from ruby.h macro hell on Windows.
#undef accept
#undef write
#undef close
#undef read
#undef bind
#undef send
#undef sleep
#undef Sleep
#undef int8_t
#undef uint8_t
#undef int16_t
#undef uint16_t
#undef int32_t
#undef uint32_t
#undef int64_t
#undef uint64_t

#include <Gosu/Gosu.hpp>
#include <Gosu/TR1.hpp>

namespace Gosu {
    void enableUndocumentedRetrofication() { extern bool undocumentedRetrofication; undocumentedRetrofication = true; }
    void releaseAllOpenALResources();
    void register_entity(const std::wstring& name, Gosu::Image* image) { registerEntity(name, image->getData().toBitmap()); }
}

#include <cstring>
#include <ctime>
#include <sstream>

// Preprocessor check for 1.9 or higher (thanks banister)
#if defined(ROBJECT_EMBED_LEN_MAX)
#define FIX_ENCODING(var) \
    rb_funcall(var, rb_intern("force_encoding"), 1, rb_str_new2("UTF-8"));
#define RUBY_18_19(r18, r19) r19
#else
#define FIX_ENCODING(var)
#define RUBY_18_19(r18, r19) r18
#endif

namespace
{
    void callRubyBlock(VALUE block) {
        rb_funcall(block, rb_intern("call"), 0);
    }
}

namespace Gosu
{
    void loadBitmap(Bitmap& bitmap, VALUE val)
    {
        // Try to treat as filename first.
        if (rb_respond_to(val, rb_intern("to_str")))
        {
            VALUE to_str = rb_funcall(val, rb_intern("to_str"), 0);
            const char* filenameUTF8 = StringValuePtr(to_str);
            std::wstring filename = Gosu::utf8ToWstring(filenameUTF8);
            loadImageFile(bitmap, filename);
            return;
        }

        // Otherwise, try to call .to_blob on it (works with RMagick, TexPlay etc).
        VALUE conversion = rb_str_new2("to_blob { self.format = 'RGBA'; self.depth = 8 }");
        VALUE blob = rb_obj_instance_eval(1, &conversion, val);
        rb_check_safe_obj(blob);
        unsigned width = NUM2ULONG(rb_funcall(val, rb_intern("columns"), 0));
        unsigned height = NUM2ULONG(rb_funcall(val, rb_intern("rows"), 0));
        
        bitmap.resize(width, height, Gosu::Color::NONE);
        if (width * height * 4 == RSTRING_LEN(blob))
        {
            // 32 bit per pixel, assume R8G8B8A8
            std::memcpy(bitmap.data(),
                reinterpret_cast<const unsigned*>(RSTRING_PTR(blob)), width * height * 4);
        }
        else if (width * height * 4 * sizeof(float) == RSTRING_LEN(blob))
        {
            // 128 bit per channel, assume float/float/float/float
            const float* in = reinterpret_cast<const float*>(RSTRING_PTR(blob));
            Gosu::Color::Channel* out = reinterpret_cast<Gosu::Color::Channel*>(bitmap.data());
            for (int i = width * height * 4; i > 0; --i)
                *(out++) = static_cast<Color::Channel>(*(in++) * 255);
        }
        else
            throw std::logic_error("Blob length mismatch!");
    }
    
    const char* cstrFromSymbol(VALUE symbol)
    {
        Check_Type(symbol, T_SYMBOL);
        return rb_id2name(SYM2ID(symbol));
    }
}
    
// Global input functions

namespace Gosu {
    Gosu::Button charToButtonId(wchar_t ch) {
        return Gosu::Input::charToId(ch);
    }
    wchar_t buttonIdToChar(Gosu::Button btn) {
        return Gosu::Input::idToChar(btn);
    }
    bool isButtonDown(Gosu::Button btn) {
        return Gosu::Input::down(btn);
    }
}

// Global graphics functions
namespace Gosu {
    void drawLine(double x1, double y1, Gosu::Color c1,
                  double x2, double y2, Gosu::Color c2,
                  Gosu::ZPos z = 0, Gosu::AlphaMode mode = Gosu::amDefault) {
        Gosu::Graphics::drawLine(x1, y1, c1, x2, y2, c2,
                                   z, mode);
    }
    void drawTriangle(double x1, double y1, Gosu::Color c1,
                      double x2, double y2, Gosu::Color c2,
                      double x3, double y3, Gosu::Color c3,
                      Gosu::ZPos z = 0, Gosu::AlphaMode mode = Gosu::amDefault) {
        Gosu::Graphics::drawTriangle(x1, y1, c1, x2, y2, c2, x3, y3, c3,
                                       z, mode);
    }
    void drawQuad(double x1, double y1, Gosu::Color c1,
                  double x2, double y2, Gosu::Color c2,
                  double x3, double y3, Gosu::Color c3,
                  double x4, double y4, Gosu::Color c4,
                  Gosu::ZPos z = 0, Gosu::AlphaMode mode = Gosu::amDefault) {
        Gosu::Graphics::drawQuad(x1, y1, c1, x2, y2, c2,
                                 x3, y3, c3, x4, y4, c4,
                                 z, mode);
    }
    void drawRect(double x, double y, double width, double height, Gosu::Color c,
                  Gosu::ZPos z = 0, Gosu::AlphaMode mode = Gosu::amDefault) {
        Gosu::Graphics::drawQuad(x, y, c, x + width, y, c,
                                 x, y + height, c, x + width, y + height, c,
                                 z, mode);
    }
    void flush() {
        return Gosu::Graphics::flush();
    }
    void unsafe_gl() {
        Gosu::Graphics::beginGL();
        rb_yield(Qnil);
        Gosu::Graphics::endGL();
    }
    void unsafe_gl(Gosu::ZPos z) {
        Gosu::Graphics::scheduleGL(std::tr1::bind(callRubyBlock, rb_block_proc()), z);
    }
    void clipTo(double x, double y, double width, double height) {
        Gosu::Graphics::beginClipping(x, y, width, height);
        rb_yield(Qnil);
        Gosu::Graphics::endClipping();
    }
    Gosu::Image* record(int width, int height) {
        Gosu::Graphics::beginRecording();
        rb_yield(Qnil);
        return new Gosu::Image(Gosu::Graphics::endRecording(width, height));
    }
    
    // This method cannot be called "transform" because then it would be an ambiguous overload of Gosu::Transform Gosu::transform(...).
    // So it has to be renamed via %rename below... :( - same for the other transformations.
    
    void transformForRuby(double m0, double m1, double m2, double m3, double m4, double m5, double m6, double m7,
        double m8, double m9, double m10, double m11, double m12, double m13, double m14, double m15) {
        Gosu::Transform transform = {
            m0, m1, m2, m3, m4, m5, m6, m7, m8, m9, m10, m11, m12, m13, m14, m15
        };
        Gosu::Graphics::pushTransform(transform);
        rb_yield(Qnil);
        Gosu::Graphics::popTransform();
    }
    void rotateForRuby(double angle, double aroundX = 0, double aroundY = 0) {
        Gosu::Graphics::pushTransform(Gosu::rotate(angle, aroundX, aroundY));
        rb_yield(Qnil);
        Gosu::Graphics::popTransform();
    }
    void scaleForRuby(double factor) {
        Gosu::Graphics::pushTransform(Gosu::scale(factor));
        rb_yield(Qnil);
        Gosu::Graphics::popTransform();
    }
    void scaleForRuby(double factorX, double factorY) {
        Gosu::Graphics::pushTransform(Gosu::scale(factorX, factorY));
        rb_yield(Qnil);
        Gosu::Graphics::popTransform();
    }
    void scaleForRuby(double factorX, double factorY, double aroundX, double aroundY) {
        Gosu::Graphics::pushTransform(Gosu::scale(factorX, factorY, aroundX, aroundY));
        rb_yield(Qnil);
        Gosu::Graphics::popTransform();
    }
    void translateForRuby(double x, double y) {
        Gosu::Graphics::pushTransform(Gosu::translate(x, y));
        rb_yield(Qnil);
        Gosu::Graphics::popTransform();
    }
}
%}

// Exception wrapping
%exception {
    try {
        $action
    } catch (const std::exception& e) {
        SWIG_exception(SWIG_RuntimeError, e.what());
    }
}

// Version constant
%rename("MAJOR_VERSION") GOSU_MAJOR_VERSION;
%rename("MINOR_VERSION") GOSU_MINOR_VERSION;
%rename("POINT_VERSION") GOSU_POINT_VERSION;
%rename("VERSION") GOSU_VERSION;
%include "../../Gosu/Version.hpp"

// Miscellaneous functions (timing, math)
%ignore Gosu::sleep;
%include "../../Gosu/Timing.hpp"
%ignore Gosu::pi;
%ignore Gosu::distanceSqr;
%ignore Gosu::round;
%ignore Gosu::trunc;
%ignore Gosu::boundBy;
%ignore Gosu::clamp;
%ignore Gosu::wrap;
%ignore Gosu::radiansToGosu;
%ignore Gosu::gosuToRadians;
%include "../../Gosu/Math.hpp"
%ignore Gosu::textWidth;
%ignore Gosu::createText;
%ignore Gosu::textHeight;
%ignore Gosu::drawText;
%ignore Gosu::registerEntity;
%include "../../Gosu/Text.hpp"


// Graphics:

// ZPos, AlphaMode, FontFlags, TextAlign
%ignore Gosu::AlphaMode;
%ignore Gosu::FontFlags;
%ignore Gosu::TextAlign;
%ignore Gosu::ImageFlags;
%ignore Gosu::concat;
%ignore Gosu::translate;
%ignore Gosu::rotate;
%ignore Gosu::scale;
%include "../../Gosu/GraphicsBase.hpp"

// For screenWidth/screenHeight
%ignore Gosu::Graphics;
%ignore Gosu::BorderFlags;
%ignore Gosu::MAX_TEXTURE_SIZE;
%include "../../Gosu/Graphics.hpp"

%constant unsigned MAX_TEXTURE_SIZE = Gosu::MAX_TEXTURE_SIZE;

%rename("_release_all_openal_resources") releaseAllOpenALResources;

namespace Gosu {
    std::string language();
    void enableUndocumentedRetrofication();
    void releaseAllOpenALResources();
    void register_entity(const std::wstring& name, Gosu::Image* image);
}

// Color
%rename("alpha=") setAlpha;
%rename("red=") setRed;
%rename("green=") setGreen;
%rename("blue=") setBlue;
%rename("hue=") setHue;
%rename("saturation=") setSaturation;
%rename("value=") setValue;
%include "std_string.i"

%ignore Gosu::Color::Channel;
%ignore Gosu::Color::argb();
%ignore Gosu::Color::bgr();
%ignore Gosu::Color::abgr();
%ignore Gosu::Color::NONE;
%ignore Gosu::Color::BLACK;
%ignore Gosu::Color::GRAY;
%ignore Gosu::Color::WHITE;
%ignore Gosu::Color::AQUA;
%ignore Gosu::Color::RED;
%ignore Gosu::Color::GREEN;
%ignore Gosu::Color::BLUE;
%ignore Gosu::Color::YELLOW;
%ignore Gosu::Color::FUCHSIA;
%ignore Gosu::Color::CYAN;

%include "../../Gosu/Color.hpp"

%extend Gosu::Color {
    static Gosu::Color rgb(Gosu::Color::Channel r, Gosu::Color::Channel g,
        Gosu::Color::Channel b)
    {
        return Gosu::Color(r, g, b);
    }
    
    static Gosu::Color rgba(Gosu::Color::Channel r, Gosu::Color::Channel g,
        Gosu::Color::Channel b, Gosu::Color::Channel a)
    {
        return Gosu::Color(a, r, g, b);
    }
    
    static Gosu::Color rgba(std::tr1::uint32_t rgba)
    {
        return Gosu::Color(rgba & 0xff, (rgba >> 24) & 0xff,
            (rgba >> 16) & 0xff, (rgba >> 8) & 0xff);
    }
    
    static Gosu::Color argb(Gosu::Color::Channel a, Gosu::Color::Channel r,
        Gosu::Color::Channel g, Gosu::Color::Channel b)
    {
        return Gosu::Color(a, r, g, b);
    }
    
    static Gosu::Color argb(std::tr1::uint32_t argb)
    {
        return Gosu::Color(argb);
    }
    
    Gosu::Color dup() const {
        return *$self;
    }

    std::string inspect() const {
        char buffer[32];
        // snprintf is either member of std:: (C++11), or a #define for ruby_snprintf.
        using namespace std;
        snprintf(buffer, sizeof buffer, "#<Gosu::Color:ARGB=0x%02x_%06x>", $self->alpha(), $self->argb() & 0xffffff);
        return buffer;
    }
    
    bool operator==(VALUE other) {
        if (TYPE(other) == T_FIXNUM || TYPE(other) == T_BIGNUM)
            return *$self == Gosu::Color(NUM2ULONG(other));
        void* ptr;
        int res = SWIG_ConvertPtr(other, &ptr, SWIGTYPE_p_Gosu__Color, 0);
        return SWIG_IsOK(res) && ptr && *$self == *reinterpret_cast<Gosu::Color*>(ptr);
    }
}

// Font
%ignore Gosu::Font::Font(unsigned height, const std::wstring& fontName,
    unsigned flags);
%ignore Gosu::Font::setImage;
%include "../../Gosu/Font.hpp"
%extend Gosu::Font {
    Font(Gosu::Window& window, const std::wstring& fontName, unsigned height) {
        return new Gosu::Font(height, fontName);
    }
    Font(unsigned height, VALUE options = 0) {
        std::wstring fontName = Gosu::defaultFontName();
        
        if (options) {
            Check_Type(options, T_HASH);
            
            VALUE keys = rb_funcall(options, rb_intern("keys"), 0, NULL);
            int keysSize = NUM2INT(rb_funcall(keys, rb_intern("size"), 0, NULL));
            
            for (int i = 0; i < keysSize; ++i) {
                VALUE key = rb_ary_entry(keys, i);
                const char* keyString = Gosu::cstrFromSymbol(key);
                
                VALUE value = rb_hash_aref(options, key);
                if (!strcmp(keyString, "name")) {
                    VALUE rbString = rb_obj_as_string(value);
                    char* utf8String = StringValueCStr(rbString);
                    fontName = Gosu::utf8ToWstring(utf8String);
                }
                // TODO - would be nice & trivial to support :bold => false and :italic => true here
                else {
                    static bool issuedWarning = false;
                    if (!issuedWarning) {
                        issuedWarning = true;
                        rb_warn("Unknown keyword argument: :%s", keyString);
                    }
                }
            }
        }
        
        return new Gosu::Font(height, fontName);
    }
    void set_image(wchar_t wc, VALUE source) {
        Gosu::Bitmap bitmap;
        Gosu::loadBitmap(bitmap, source);
        $self->setImage(wc, Gosu::Image(bitmap, Gosu::ifSmooth));
    }
}

%ignore Gosu::ImageData;
%rename("tex_name") texName;
%include "../../Gosu/ImageData.hpp"

// Image

// Typemap to return an array of images (for loadTiles)
%typemap(out) std::vector<Gosu::Image> {
    $result = rb_ary_new2($1.size());
    for (unsigned i = 0; i < $1.size(); i++) {
        VALUE image = SWIG_NewPointerObj(SWIG_as_voidptr(new Gosu::Image((*&$1)[i])), SWIGTYPE_p_Gosu__Image, SWIG_POINTER_OWN);
        rb_ary_store($result, i, image);
    }
}

%ignore Gosu::Image::Image(const std::wstring& filename, unsigned flags);
%ignore Gosu::Image::Image(const std::wstring& filename, unsigned srcX, unsigned srcY, unsigned srcWidth, unsigned srcHeight, unsigned flags);
%ignore Gosu::Image::Image(const Bitmap& source, unsigned flags);
%ignore Gosu::Image::Image(const Bitmap& source, unsigned srcX, unsigned srcY, unsigned srcWidth, unsigned srcHeight, unsigned flags);
%ignore Gosu::Image::Image(GOSU_UNIQUE_PTR<ImageData> data);
%ignore Gosu::loadTiles;
%include "../../Gosu/Image.hpp"
%extend Gosu::Image {
    Image(VALUE source, VALUE options = 0) {
        Gosu::Bitmap bmp;
        Gosu::loadBitmap(bmp, source);
        
        unsigned srcX = 0, srcY = 0, srcWidth = bmp.width(), srcHeight = bmp.height();
        unsigned flags = 0;
        
        if (options) {
            Check_Type(options, T_HASH);
            
            VALUE keys = rb_funcall(options, rb_intern("keys"), 0, NULL);
            int keysSize = NUM2INT(rb_funcall(keys, rb_intern("size"), 0, NULL));
            
            for (int i = 0; i < keysSize; ++i) {
                VALUE key = rb_ary_entry(keys, i);
                const char* keyString = Gosu::cstrFromSymbol(key);
                
                VALUE value = rb_hash_aref(options, key);
                if (!strcmp(keyString, "tileable")) {
                    if (RTEST(value))
                        flags |= Gosu::ifTileable;
                }
                else if (!strcmp(keyString, "retro")) {
                    if (RTEST(value))
                        flags |= Gosu::ifRetro;
                }
                else if (!strcmp(keyString, "rect")) {
                    Check_Type(value, T_ARRAY);
                    
                    int rectSize = NUM2INT(rb_funcall(value, rb_intern("size"), 0, NULL));
                    if (rectSize != 4)
                        rb_raise(rb_eArgError, "Argument passed to :rect must be a four-element Array (x, y, width, height)");
                    
                    srcX = NUM2INT(rb_ary_entry(value, 0));
                    srcY = NUM2INT(rb_ary_entry(value, 1));
                    srcWidth = NUM2INT(rb_ary_entry(value, 2));
                    srcHeight = NUM2INT(rb_ary_entry(value, 3));
                }
                else {
                    static bool issuedWarning = false;
                    if (!issuedWarning) {
                        issuedWarning = true;
                        rb_warn("Unknown keyword argument: :%s", keyString);
                    }
                }
            }
        }
        
        return new Gosu::Image(bmp, srcX, srcY, srcWidth, srcHeight, flags);
    }
    void drawAsQuad(double x1, double y1, Color c1,
            double x2, double y2, Color c2,
            double x3, double y3, Color c3,
            double x4, double y4, Color c4,
            ZPos z, AlphaMode mode = Gosu::amDefault) {
        $self->getData().draw(x1, y1, c1, x2, y2, c2, x3, y3, c3, x4, y4, c4, z, mode);
    }
    %newobject glTexInfo;
    Gosu::GLTexInfo* glTexInfo() const {
        const Gosu::GLTexInfo* info = $self->getData().glTexInfo();
        if (info)
            return new Gosu::GLTexInfo(*info);
        else
            return 0;
    }
    %newobject subimage;
    Gosu::Image* subimage(int x, int y, int w, int h)
    {
        GOSU_UNIQUE_PTR<Gosu::ImageData> imageData = $self->getData().subimage(x, y, w, h);
        return imageData.get() ? new Gosu::Image(GOSU_MOVE_UNIQUE_PTR(imageData)) : 0;
    }
    
    %newobject fromText;
    static Gosu::Image* fromText(const std::wstring& text, unsigned fontHeight, VALUE options = 0)
    {
        std::wstring font = Gosu::defaultFontName();
        unsigned width = 0xfefefefe;
        unsigned spacing = 0;
        Gosu::TextAlign align = Gosu::taLeft;
        unsigned flags = 0;
        
        if (options) {
            Check_Type(options, T_HASH);
            
            VALUE keys = rb_funcall(options, rb_intern("keys"), 0, NULL);
            int keysSize = NUM2INT(rb_funcall(keys, rb_intern("size"), 0, NULL));
            
            for (int i = 0; i < keysSize; ++i) {
                VALUE key = rb_ary_entry(keys, i);
                const char* keyString = Gosu::cstrFromSymbol(key);
                
                VALUE value = rb_hash_aref(options, key);
                if (!strcmp(keyString, "font")) {
                    const char* fontUTF8 = StringValuePtr(value);
                    font = Gosu::utf8ToWstring(fontUTF8);
                }
                else if (!strcmp(keyString, "align")) {
                    const char* cstr = Gosu::cstrFromSymbol(value);

                    if (!strcmp(cstr, "left"))
                        align = Gosu::taLeft;
                    else if (!strcmp(cstr, "center"))
                        align = Gosu::taCenter;
                    else if (!strcmp(cstr, "right"))
                        align = Gosu::taRight;
                    else if (!strcmp(cstr, "justify"))
                        align = Gosu::taJustify;
                    else
                        rb_raise(rb_eArgError, "Argument passed to :align must be a valid text alignment (:left, :center, :right, :justify)");
                }
                else if (!strcmp(keyString, "width")) {
                    width = NUM2INT(value);
                }
                else if (!strcmp(keyString, "spacing")) {
                    spacing = NUM2INT(value);
                }
                else if (!strcmp(keyString, "retro")) {
                    if (RTEST(value))
                        flags |= Gosu::ifRetro;
                }
                else {
                    static bool issuedWarning = false;
                    if (!issuedWarning) {
                        issuedWarning = true;
                        rb_warn("Unknown keyword argument: :%s", keyString);
                    }
                }
            }
        }
        
        if (width == 0xfefefefe)
            return new Gosu::Image(Gosu::createText(text, font, fontHeight), flags);
        else
            return new Gosu::Image(Gosu::createText(text, font, fontHeight, spacing, width, align), flags);
    }
    static std::vector<Gosu::Image> loadTiles(VALUE source, int tileWidth, int tileHeight, VALUE options = 0)
    {
        Gosu::Bitmap bmp;
        Gosu::loadBitmap(bmp, source);
        
        unsigned flags = 0;
        
        if (options) {
            Check_Type(options, T_HASH);
            
            VALUE keys = rb_funcall(options, rb_intern("keys"), 0, NULL);
            int keysSize = NUM2INT(rb_funcall(keys, rb_intern("size"), 0, NULL));
            
            for (int i = 0; i < keysSize; ++i) {
                VALUE key = rb_ary_entry(keys, i);
                const char* keyString = Gosu::cstrFromSymbol(key);
                
                VALUE value = rb_hash_aref(options, key);
                if (!strcmp(keyString, "tileable")) {
                    if (RTEST(value))
                        flags |= Gosu::ifTileable;
                }
                else if (!strcmp(keyString, "retro")) {
                    if (RTEST(value))
                        flags |= Gosu::ifRetro;
                }
                else {
                    static bool issuedWarning = false;
                    if (!issuedWarning) {
                        issuedWarning = true;
                        rb_warn("Unknown keyword argument: :%s", keyString);
                    }
                }
            }
        }
        return Gosu::loadTiles(bmp, tileWidth, tileHeight, flags);
    }
    static std::vector<Gosu::Image> loadTiles(Gosu::Window& window,
            VALUE source, int tileWidth, int tileHeight, bool tileable)
    {
        Gosu::Bitmap bmp;
        Gosu::loadBitmap(bmp, source);
        
        return Gosu::loadTiles(bmp, tileWidth, tileHeight, tileable ? Gosu::ifTileable : Gosu::ifSmooth);
    }
    std::string toBlob() const
    {
        // TODO: Optimize with direct copy into a Ruby string
        Gosu::Bitmap bmp = $self->getData().toBitmap();
        return std::string(reinterpret_cast<const char*>(bmp.data()),
                           reinterpret_cast<const char*>(bmp.data()) + bmp.width() * bmp.height() * 4);
    }
    unsigned columns() const
    {
        return $self->width();
    }
    unsigned rows() const
    {
        return $self->height();
    }
    void save(const std::wstring& filename) const
    {
        Gosu::saveImageFile($self->getData().toBitmap(), filename);
    }
    void insert(VALUE source, int x, int y)
    {
        Gosu::Bitmap bmp;
        Gosu::loadBitmap(bmp, source);
        $self->getData().insert(bmp, x, y);
    }
}

// Inspection:

%include "../../Gosu/Inspection.hpp"


// Audio:

%ignore Gosu::Sample::Sample(Reader reader);
%ignore Gosu::Song::Song(Reader reader);
%rename("playing?") playing;
%rename("paused?") paused;
%rename("volume=") changeVolume;
%rename("pan=") changePan;
%rename("speed=") changeSpeed;
%include "../../Gosu/Audio.hpp"

// Input and Window:

// Button ID constants
%ignore Gosu::kbRangeBegin;
%ignore Gosu::kbRangeEnd;
%ignore Gosu::msRangeBegin;
%ignore Gosu::msRangeEnd;
%ignore Gosu::gpRangeBegin;
%ignore Gosu::gpRangeEnd;
%ignore Gosu::kbNum;
%ignore Gosu::msNum;
%ignore Gosu::gpNum;
%ignore Gosu::gpNumPerGamepad;
%ignore Gosu::numButtons;
%ignore Gosu::numGamepads;
%ignore Gosu::noButton;
%include "../../Gosu/Buttons.hpp"
%init %{
    // Call srand() so that Gosu::random() is actually random in Ruby scripts
    std::srand(static_cast<unsigned int>(std::time(0)));
    std::rand(); // and flush the first value
%}

// TextInput
%ignore Gosu::TextInput::feedNSEvent(void*);
%ignore Gosu::TextInput::feedSDLEvent(void*);
%ignore Gosu::TextInput::feedMessage(unsigned long, unsigned long, unsigned long);
%ignore Gosu::TextInput::feedButtonId(unsigned);
%ignore Gosu::TextInput::caretPos() const;
%ignore Gosu::TextInput::selectionStart() const;
%rename("text=") setText;
%rename("caret_pos=") setCaretPos;
%rename("selection_start=") setSelectionStart;
%include "../../Gosu/TextInput.hpp"
%extend Gosu::TextInput {
    // Fix indices into UTF-8 string
    unsigned caret_pos() const {
        return RUBY_18_19(Gosu::wstringToUTF8($self->text().substr(0, $self->caretPos())).size(),
            $self->caretPos());
    }
    unsigned selection_start() const {
        return RUBY_18_19(Gosu::wstringToUTF8($self->text().substr(0, $self->selectionStart())).size(),
            $self->selectionStart());
    }
};

// Window
%rename("caption=") setCaption;
%rename("text_input=") setTextInput;
%rename("mouse_x=") setMouseX;
%rename("mouse_y=") setMouseY;
%rename("needs_cursor?") needsCursor;
%rename("needs_redraw?") needsRedraw;
%rename("fullscreen?") fullscreen;
%markfunc Gosu::Window "markWindow";
%include "../../Gosu/Window.hpp"

// TODO: Can I fake this using an @ivar?
%header %{
    static void markWindow(void* window) {
        #ifndef __MACRUBY__
        Gosu::TextInput* ti = static_cast<Gosu::Window*>(window)->input().textInput();
        if (VALUE ti_value = SWIG_RubyInstanceFor(ti))
            rb_gc_mark(ti_value);
        #endif
    }
%}

%extend Gosu::Window {
    /* Does not work - SWIG's director does not pick up this constructor.
       Defined in pure Ruby instead, see lib/gosu/swig_patches.rb.
       
       TODO: File a bug?!
    
    Window(unsigned width, unsigned height, VALUE optionsOrFullscreen) {
        double updateInterval = 16.666666;
        bool fullscreen = false;
        
        if (TYPE(optionsOrFullscreen) == T_HASH) {
            VALUE keys = rb_funcall(optionsOrFullscreen, rb_intern("keys"), 0, NULL);
            int keysSize = NUM2INT(rb_funcall(keys, rb_intern("size"), 0, NULL));
            
            for (int i = 0; i < keysSize; ++i) {
                VALUE key = rb_ary_entry(keys, i);
                const char* keyString = Gosu::cstrFromSymbol(key);
                
                VALUE value = rb_hash_aref(optionsOrFullscreen, key);
                if (!strcmp(keyString, "fullscreen")) {
                    fullscreen = RTEST(value);
                }
                else if (!strcmp(keyString, "update_interval")) {
                    updateInterval = NUM2DBL(value);
                }
                else {
                    static bool issuedWarning = false;
                    if (!issuedWarning) {
                        issuedWarning = true;
                        rb_warn("Unknown keyword argument: :%s", keyString);
                    }
                }
            }
        }
        else {
            fullscreen = RTEST(optionsOrFullscreen);
        }
        
        return new Gosu::Window(width, height, fullscreen, updateInterval);
    }
    */
    
    TextInput* textInput() const {
        return $self->input().textInput();
    }
    void setTextInput(TextInput* ti) {
        $self->input().setTextInput(ti);
    }
    
    double mouseX() const {
        return $self->input().mouseX();
    }
    double mouseY() const {
        return $self->input().mouseY();
    }
    void setMousePosition(double x, double y) {
        $self->input().setMousePosition(x, y);
    }
    void setMouseX(double x) {
        $self->input().setMousePosition(x, $self->input().mouseY());
    }
    void setMouseY(double y) {
        $self->input().setMousePosition($self->input().mouseX(), y);
    }
    
    int width() const {
        return $self->graphics().width();
    }
    int height() const {
        return $self->graphics().height();
    }
    bool fullscreen() const {
        return $self->graphics().fullscreen();
    }
};

// Global input functions

namespace Gosu {
    Gosu::Button charToButtonId(wchar_t ch);
    wchar_t buttonIdToChar(Gosu::Button btn);
    %rename("button_down?") isButtonDown;
    bool isButtonDown(Gosu::Button btn);
}

// Global graphics functions
namespace Gosu {
    void drawLine(double x1, double y1, Gosu::Color c1,
                  double x2, double y2, Gosu::Color c2,
                  Gosu::ZPos z = 0, Gosu::AlphaMode mode = Gosu::amDefault);
    void drawTriangle(double x1, double y1, Gosu::Color c1,
                      double x2, double y2, Gosu::Color c2,
                      double x3, double y3, Gosu::Color c3,
                      Gosu::ZPos z = 0, Gosu::AlphaMode mode = Gosu::amDefault);
    void drawQuad(double x1, double y1, Gosu::Color c1,
                  double x2, double y2, Gosu::Color c2,
                  double x3, double y3, Gosu::Color c3,
                  double x4, double y4, Gosu::Color c4,
                  Gosu::ZPos z = 0, Gosu::AlphaMode mode = Gosu::amDefault);
    void drawRect(double x, double y, double width, double height, Gosu::Color c,
                  Gosu::ZPos z = 0, Gosu::AlphaMode mode = Gosu::amDefault);
    void flush();
    void unsafe_gl();
    void unsafe_gl(Gosu::ZPos z);
    void clipTo(double x, double y, double width, double height);
    %newobject record;
    Gosu::Image* record(int width, int height);
    
    %rename("transform") transformForRuby;
    %rename("rotate")    rotateForRuby;
    %rename("scale")     scaleForRuby;
    %rename("translate") translateForRuby;
    
    void transformForRuby(double m0, double m1, double m2, double m3, double m4, double m5, double m6, double m7,
        double m8, double m9, double m10, double m11, double m12, double m13, double m14, double m15);
    void rotateForRuby(double angle, double aroundX = 0, double aroundY = 0);
    void scaleForRuby(double factor);
    void scaleForRuby(double factorX, double factorY);
    void scaleForRuby(double factorX, double factorY, double aroundX, double aroundY);
    void translateForRuby(double x, double y);
}

