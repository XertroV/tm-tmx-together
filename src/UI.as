// should all be free/instant to load
UI::Font@ subheadingFont = UI::LoadFont("DroidSans-Bold.ttf", 16);
UI::Font@ headingFont = UI::LoadFont("DroidSans.ttf", 20);
UI::Font@ titleFont = UI::LoadFont("DroidSans.ttf", 26);


void SubHeading(const string &in text) {
    UI::PushFont(subheadingFont);
    UI::AlignTextToFramePadding();
    UI::Text(text);
    UI::PopFont();
}
