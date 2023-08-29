// should all be free/instant to load
UI::Font@ subheadingFont = UI::LoadFont("DroidSans-Bold.ttf", 16);
UI::Font@ headingFont = UI::LoadFont("DroidSans.ttf", 20);
UI::Font@ titleFont = UI::LoadFont("DroidSans.ttf", 26);


void SubHeading(const string &in text) {
    if (S_FontSize == FontSize::S16)
        UI::PushFont(subheadingFont);
    else if (S_FontSize == FontSize::S16_Bold)
        UI::PushFont(headingFont);
    else // if (S_FontSize == FontSize::S20)
        UI::PushFont(titleFont);

    UI::AlignTextToFramePadding();
    UI::Text(text);
    UI::PopFont();
}
