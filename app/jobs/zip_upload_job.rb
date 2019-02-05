class ZipUploadJob < Struct.new(:album_id)
  def enqueue(job)
    Delayed::Job.all do |j|
      if j.name == job.name then
        j.delete
      end
    end
  end

  def perform
    album = Album.find(album_id)
    album.generate_zip
  end

  def display_name
    return "ZipUploadJob-Album-#{album_id}"
  end
end