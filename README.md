# podomation

**What is Podomation?**
  - it's an OSS framework of tools used to automate the mixing, remixing and reposting of podcast audio files
  - you can use it for frequent remixing of dynamic podcast audio content (e.g. pre-roll, intros, advertisement, announcements, etc)
  - it can be customized to work with any target podcast platform or service provider
  - you can customize it to initate a podcast transcription via Amazon's automated transcription

**What's the current status of Podomation?**
  - A work in-progress. 
  - We are thinking about how we package and distribute this, perhaps via pre-made Docker image?
  - we want to make it easier and more accessible to podcasters of all technical levels.
  - it is intentionally very simple bash scripting to avoid undue complexity

**How does Podomation work?**
  - using a Rundeck job dispatcher to run a bash script...
  - you define your audio clips in a text file...
  - the job will combine the clips using sox audio (http://sox.sourceforge.net/)
  - then it will convert the output into an .mp3 using ffmpeg (https://www.ffmpeg.org/)
  - then it can use FTP to upload to Blubrry
  - and then you can initiate an automated transcription for the podcast
 
**What else can Podomation do for you?**
  - it can remix and replace the podcast audio clips with new content (e.g. a new pre-roll advertisement, or announcement, or theme music)
  - it can download new episodes from your podcast .xml file and create your initial folders/files; setup for new shows
  - it can support multiple producers, shows and episodes

Reference notes:

there are folders: clips = audio clips that are shared across the episodes episodes = working folders, 1 for each episode

the episode folder contains: info file = the metadata and "control file" for the podomation sequence Segment file(s) = the .wavs that are the episode audio Mixdown audio = the compressed .mp3 or .m4a file that is uploaded to the web backups = a folder with the history of all .mp3 or .m4a that were ever remixed

audio format for = 24-bit/48kHz ...all the .wavs are made to
