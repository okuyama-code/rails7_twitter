# frozen_string_literal: true

class User < ApplicationRecord
  validates :uid, uniqueness: { scope: :provider }, if: -> { uid.present? }
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: [:github]
  validates :name, presence: true

  has_one_attached :icon
  has_one_attached :header

  has_many :posts, dependent: :destroy
  has_many :comments # User.commentsで、ユーザーの所有するコメントを取得できる。
  has_many :likes, dependent: :destroy
  has_many :bookmarks, dependent: :destroy

  has_many :reposts, dependent: :destroy

  has_many :relationships, foreign_key: :following_id
  has_many :followings, through: :relationships, source: :follower

  has_many :reverse_of_relationships, class_name: 'Relationship', foreign_key: :follower_id
  has_many :followers, through: :reverse_of_relationships, source: :following

  # DM機能
  has_many :messages, dependent: :destroy
  has_many :entries, dependent: :destroy

  # 通知機能
  has_many :active_notifications, class_name: 'Notification', foreign_key: 'visitor_id', dependent: :destroy
  has_many :passive_notifications, class_name: 'Notification', foreign_key: 'visited_id', dependent: :destroy

  def already_liked?(post)
    likes.exists?(post_id: post.id)
    # selfにはcurrent_userが入る
  end

  def already_bookmark?(post)
    bookmarks.exists?(post_id: post.id)
    # selfにはcurrent_userが入る
  end

  def reposted?(post_id)
    reposts.where(post_id:).exists?
  end

  def is_followed_by?(user)
    reverse_of_relationships.find_by(following_id: user.id).present?
  end

  def create_notification_follow!(current_user)
    temp = Notification.where(['visitor_id = ? and visited_id = ? and action = ? ', current_user.id, id, 'follow'])
    return if temp.present?

    notification = current_user.active_notifications.new(
      visited_id: id,
      action: 'follow'
    )
    notification.save if notification.valid?
  end

  def self.from_omniauth(auth)
    where(provider: auth.provider, uid: auth.uid).first_or_create! do |u|
      u.name = auth.info.name
      u.email = auth.info.email
      u.password = Devise.friendly_token[0, 20]
      u.date_of_birth = '1995-01-01'
      u.telephone = '08000001111'
      u.username = auth.info.nickname
      # u.icon.attach(io: File.open(Rails.root.join('app/assets/images/icon.png')), filename: 'icon.png')
      # u.header.attach(io: File.open(Rails.root.join('app/assets/images/header.jpg')), filename: 'header.jpg')
    end
  end

  after_create :send_welcome_mail

  def send_welcome_mail
    UserNoticeMailer.send_signup_email(self).deliver_now
  end

  before_create :attach_default_image

  def attach_default_image
    icon.attach(io: File.open(Rails.root.join('app/assets/images/suisu2.jpg')), filename: 'suisu2.jpg')
    header.attach(io: File.open(Rails.root.join('app/assets/images/header.jpg')), filename: 'header.jpg')
end

end
