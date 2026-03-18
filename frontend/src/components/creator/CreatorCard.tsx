import Link from "next/link";
import { CreatorWithProfile } from "@/lib/types";
import { formatPrice } from "@/lib/auth";

interface Props {
  creator: CreatorWithProfile;
}

export function CreatorCard({ creator }: Props) {
  const { user, profile } = creator;

  return (
    <Link href={`/${user.username}`} className="card block overflow-hidden hover:shadow-md transition-shadow">
      {/* Cover */}
      <div className="h-32 bg-gradient-to-r from-brand-500 to-purple-500">
        {profile.cover_url && (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={profile.cover_url} alt="" className="h-full w-full object-cover" />
        )}
      </div>

      {/* Body */}
      <div className="p-4 pt-0">
        <div className="-mt-8 mb-3">
          {user.avatar_url ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={user.avatar_url}
              alt={user.username}
              className="h-16 w-16 rounded-full border-4 border-white object-cover shadow"
            />
          ) : (
            <div className="flex h-16 w-16 items-center justify-center rounded-full border-4 border-white bg-brand-100 text-xl font-bold text-brand-600 shadow">
              {profile.display_name[0].toUpperCase()}
            </div>
          )}
        </div>

        <h3 className="font-semibold truncate">{profile.display_name}</h3>
        <p className="text-sm text-gray-400">@{user.username}</p>

        {profile.category && (
          <span className="mt-2 inline-block rounded-full bg-gray-100 px-2 py-0.5 text-xs text-gray-500">
            {profile.category}
          </span>
        )}

        {profile.description && (
          <p className="mt-2 text-sm text-gray-600 line-clamp-2">{profile.description}</p>
        )}

        <div className="mt-3 border-t pt-3">
          <span className="text-sm font-medium text-brand-600">
            {formatPrice(profile.subscription_price_cents)}
          </span>
        </div>
      </div>
    </Link>
  );
}
