#pragma once

// The public package currently consumes the legacy TagLib.framework release,
// while the next binary revision uses a namespaced framework to avoid host-app
// collisions. Keep the bridge source compatible with both binary layouts
// during that migration.
#if __has_include(<TagLibAudioMetadataTagLib/taglib.h>)
#define TL_TAGLIB_HEADER(name) <TagLibAudioMetadataTagLib/name>
#else
#define TL_TAGLIB_HEADER(name) <TagLib/name>
#endif

#include TL_TAGLIB_HEADER(fileref.h)
#include TL_TAGLIB_HEADER(tag.h)
#include TL_TAGLIB_HEADER(audioproperties.h)
#include TL_TAGLIB_HEADER(tpropertymap.h)

#include TL_TAGLIB_HEADER(mpegfile.h)
#include TL_TAGLIB_HEADER(id3v1tag.h)
#include TL_TAGLIB_HEADER(id3v2tag.h)
#include TL_TAGLIB_HEADER(id3v2frame.h)
#include TL_TAGLIB_HEADER(attachedpictureframe.h)
#include TL_TAGLIB_HEADER(textidentificationframe.h)
#include TL_TAGLIB_HEADER(commentsframe.h)
#include TL_TAGLIB_HEADER(unsynchronizedlyricsframe.h)
#include TL_TAGLIB_HEADER(popularimeterframe.h)
#include TL_TAGLIB_HEADER(urllinkframe.h)
#include TL_TAGLIB_HEADER(uniquefileidentifierframe.h)
#include TL_TAGLIB_HEADER(chapterframe.h)
#include TL_TAGLIB_HEADER(tableofcontentsframe.h)
#include TL_TAGLIB_HEADER(podcastframe.h)

#include TL_TAGLIB_HEADER(mp4file.h)
#include TL_TAGLIB_HEADER(mp4tag.h)
#include TL_TAGLIB_HEADER(mp4item.h)
#include TL_TAGLIB_HEADER(mp4coverart.h)

#include TL_TAGLIB_HEADER(flacfile.h)
#include TL_TAGLIB_HEADER(flacpicture.h)
#include TL_TAGLIB_HEADER(xiphcomment.h)
#include TL_TAGLIB_HEADER(asftag.h)
#include TL_TAGLIB_HEADER(asfattribute.h)
#include TL_TAGLIB_HEADER(asfpicture.h)

#include TL_TAGLIB_HEADER(vorbisfile.h)
#include TL_TAGLIB_HEADER(opusfile.h)
#include TL_TAGLIB_HEADER(oggflacfile.h)

#include TL_TAGLIB_HEADER(apefile.h)
#include TL_TAGLIB_HEADER(apetag.h)

#include TL_TAGLIB_HEADER(wavfile.h)
#include TL_TAGLIB_HEADER(aifffile.h)
#include TL_TAGLIB_HEADER(wavpackfile.h)
#include TL_TAGLIB_HEADER(trueaudiofile.h)

#include TL_TAGLIB_HEADER(mpcfile.h)
#include TL_TAGLIB_HEADER(speexfile.h)
#include TL_TAGLIB_HEADER(asffile.h)

#include TL_TAGLIB_HEADER(dsffile.h)
#include TL_TAGLIB_HEADER(dsdifffile.h)
#include TL_TAGLIB_HEADER(shortenfile.h)
#include TL_TAGLIB_HEADER(modfile.h)
#include TL_TAGLIB_HEADER(s3mfile.h)
#include TL_TAGLIB_HEADER(itfile.h)
#include TL_TAGLIB_HEADER(xmfile.h)

#include TL_TAGLIB_HEADER(tstring.h)
#include TL_TAGLIB_HEADER(tstringlist.h)

#undef TL_TAGLIB_HEADER
